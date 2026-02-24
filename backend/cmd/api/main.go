package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"os"
	"path"
	"path/filepath"
	"strconv"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
	"golang.org/x/crypto/bcrypt"
)

type contextKey string

const userContextKey contextKey = "auth_user"

type authUser struct {
	UserID      string `json:"user_id"`
	Email       string `json:"email"`
	Username    string `json:"username"`
	DisplayName string `json:"display_name"`
	AvatarURL   string `json:"avatar_url"`
	IsActive    bool   `json:"is_active"`
}

type fnKind string

const (
	kindScalar    fnKind = "scalar"
	kindExec      fnKind = "exec"
	kindTableList fnKind = "table_list"
	kindTableOne  fnKind = "table_one"
)

type fnDef struct {
	Kind          fnKind
	AuthRequired  bool
	InjectUserArg *int
}

type rpcRequest struct {
	Args []any `json:"args"`
}

type rpcResponse struct {
	Function string          `json:"function"`
	Kind     fnKind          `json:"kind"`
	Data     json.RawMessage `json:"data,omitempty"`
	OK       bool            `json:"ok"`
}

type app struct {
	db           *pgxpool.Pool
	fns          map[string]fnDef
	storageRoot  string
	internalAuth string
	cookieSecure bool
}

func main() {
	ctx := context.Background()
	databaseURL := envOrDefault("DATABASE_URL", "postgres://app@localhost:5432/app?sslmode=disable")
	port := envOrDefault("PORT", "8080")

	pool, err := pgxpool.New(ctx, databaseURL)
	if err != nil {
		log.Fatalf("pgxpool connect: %v", err)
	}
	defer pool.Close()

	if err := pool.Ping(ctx); err != nil {
		log.Fatalf("pg ping: %v", err)
	}

	a := &app{
		db:           pool,
		fns:          buildFunctionRegistry(),
		storageRoot:  envOrDefault("STORAGE_ROOT", filepath.Join("..", "uploads")),
		internalAuth: strings.TrimSpace(os.Getenv("INTERNAL_API_TOKEN")),
		cookieSecure: envBoolDefault("COOKIE_SECURE", false),
	}

	r := chi.NewRouter()
	r.Use(middleware.RequestID)
	r.Use(middleware.RealIP)
	r.Use(middleware.Recoverer)
	r.Use(middleware.Logger)
	r.Use(a.optionalAuth)

	r.Get("/healthz", a.handleHealth)
	r.Post("/auth/register", a.handleAuthRegister)
	r.Post("/auth/login", a.handleAuthLogin)
	r.Post("/auth/logout", a.handleAuthLogout)
	r.Get("/auth/me", a.handleMe)
	r.Get("/api/me", a.handleMe)
	r.Post("/api/v1/rpc/{function}", a.handleRPC)

	// REST API (kept alongside RPC)
	r.Route("/users", func(r chi.Router) {
		r.Get("/{userId}", a.handleGetUserProfile)
		r.Post("/{userId}/follow", a.handleFollowUser)
		r.Delete("/{userId}/follow", a.handleUnfollowUser)
		r.Get("/{userId}/videos", a.handleListUserVideos)
	})

	r.Route("/me", func(r chi.Router) {
		r.Get("/following", a.handleListMyFollowing)
		r.Get("/followers", a.handleListMyFollowers)
		r.Get("/videos", a.handleListMyVideos)

		r.Get("/folders", a.handleListMyFolders)
		r.Get("/folders/tree", a.handleListMyFolderTree)
		r.Post("/folders", a.handleCreateMyFolder)
		r.Get("/folders/{folderId}", a.handleGetMyFolder)
		r.Patch("/folders/{folderId}", a.handlePatchMyFolder)
		r.Delete("/folders/{folderId}", a.handleDeleteMyFolder)
		r.Get("/folders/{folderId}/videos", a.handleListMyFolderVideos)
		r.Post("/folders/{folderId}/videos", a.handleAddVideoToMyFolder)
		r.Delete("/folders/{folderId}/videos/{videoId}", a.handleRemoveVideoFromMyFolder)
		r.Post("/folders/{folderId}/videos/{videoId}/move", a.handleMoveVideoBetweenMyFolders)

		r.Get("/favorites", a.handleListMyFavorites)
		r.Put("/favorites/{videoId}", a.handlePutFavorite)
		r.Delete("/favorites/{videoId}", a.handleDeleteFavorite)
		r.Get("/favorites/{videoId}", a.handleGetFavoriteState)

		r.Get("/purchases", a.handleListMyPurchases)
		r.Get("/purchases/{purchaseId}", a.handleGetMyPurchase)
	})

	r.Route("/videos", func(r chi.Router) {
		r.Post("/", a.handleCreateVideo)
		r.Get("/{videoId}", a.handleGetVideo)
		r.Patch("/{videoId}", a.handlePatchVideo)
		r.Delete("/{videoId}", a.handleDeleteVideo)
		r.Post("/{videoId}/publish", a.handlePublishVideo)
		r.Post("/{videoId}/unpublish", a.handleUnpublishVideo)
		r.Get("/{videoId}/playback", a.handleGetVideoPlayback)
		r.Get("/{videoId}/download", a.handleGetVideoDownload)

		r.Get("/{videoId}/reaction", a.handleGetVideoReaction)
		r.Put("/{videoId}/reaction", a.handlePutVideoReaction)
		r.Get("/{videoId}/reactions", a.handleListVideoReactions)

		r.Get("/{videoId}/comments", a.handleListVideoComments)
		r.Post("/{videoId}/comments", a.handleCreateVideoComment)
		r.Patch("/{videoId}/comments/{commentId}", a.handlePatchVideoComment)
		r.Delete("/{videoId}/comments/{commentId}", a.handleDeleteVideoComment)

		r.Post("/{videoId}/purchase-download", a.handleCreatePurchaseDownload)
		r.Post("/{videoId}/download-token", a.handleIssueDownloadToken)
	})

	r.Route("/feed", func(r chi.Router) {
		r.Get("/following", a.handleFeedFollowing)
		r.Get("/hot", a.handleFeedHot)
		r.Get("/", a.handleFeedCombined)
	})

	r.Post("/purchases/{purchaseId}/status", a.handleSetPurchaseStatus)

	r.Route("/internal/transcode", func(r chi.Router) {
		r.Post("/enqueue", a.handleInternalTranscodeEnqueue)
		r.Post("/claim", a.handleInternalTranscodeClaim)
		r.Post("/finish", a.handleInternalTranscodeFinish)
		r.Post("/assets", a.handleInternalTranscodeAssets)
	})

	r.Get("/stream/hls/{videoId}/*", a.handleStreamHLS)

	srv := &http.Server{
		Addr:              ":" + port,
		Handler:           r,
		ReadTimeout:       10 * time.Second,
		ReadHeaderTimeout: 5 * time.Second,
		WriteTimeout:      30 * time.Second,
		IdleTimeout:       60 * time.Second,
	}

	log.Printf("backend started on :%s", port)
	if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
		log.Fatalf("http server: %v", err)
	}
}

func buildFunctionRegistry() map[string]fnDef {
	idx0 := 0
	idx1 := 1
	idx2 := 2
	idx3 := 3
	return map[string]fnDef{
		// Auth
		"auth_token_hash":               {Kind: kindScalar},
		"auth_create_session":           {Kind: kindTableOne},
		"auth_delete_session":           {Kind: kindScalar},
		"auth_get_user_by_session":      {Kind: kindTableOne},
		"auth_cleanup_expired_sessions": {Kind: kindScalar},

		// Access
		"can_view_video":     {Kind: kindScalar},
		"can_download_video": {Kind: kindScalar, AuthRequired: true, InjectUserArg: &idx0},

		// Follows
		"follow_create":         {Kind: kindScalar, AuthRequired: true, InjectUserArg: &idx0},
		"follow_delete":         {Kind: kindScalar, AuthRequired: true, InjectUserArg: &idx0},
		"follow_is_following":   {Kind: kindScalar, AuthRequired: true, InjectUserArg: &idx0},
		"follow_list_following": {Kind: kindTableList, AuthRequired: true, InjectUserArg: &idx0},
		"follow_list_followers": {Kind: kindTableList},

		// Video core
		"video_create":            {Kind: kindScalar, AuthRequired: true, InjectUserArg: &idx0},
		"video_update_metadata":   {Kind: kindScalar, AuthRequired: true, InjectUserArg: &idx0},
		"video_publish":           {Kind: kindScalar, AuthRequired: true, InjectUserArg: &idx0},
		"video_unpublish":         {Kind: kindScalar, AuthRequired: true, InjectUserArg: &idx0},
		"video_delete":            {Kind: kindScalar, AuthRequired: true, InjectUserArg: &idx0},
		"video_get":               {Kind: kindTableOne},
		"video_list_public_feed":  {Kind: kindTableList},
		"video_list_owner":        {Kind: kindTableList, AuthRequired: true, InjectUserArg: &idx0},
		"video_list_user_visible": {Kind: kindTableList},

		// Folder/favorites/library
		"folder_create":                      {Kind: kindScalar, AuthRequired: true, InjectUserArg: &idx0},
		"folder_add_video":                   {Kind: kindExec, AuthRequired: true, InjectUserArg: &idx2},
		"folder_get":                         {Kind: kindTableOne, AuthRequired: true, InjectUserArg: &idx1},
		"folder_list_children":               {Kind: kindTableList, AuthRequired: true, InjectUserArg: &idx0},
		"folder_list_videos":                 {Kind: kindTableList, AuthRequired: true, InjectUserArg: &idx1},
		"favorites_list_videos":              {Kind: kindTableList, AuthRequired: true, InjectUserArg: &idx0},
		"folder_rename":                      {Kind: kindScalar, AuthRequired: true, InjectUserArg: &idx1},
		"folder_move":                        {Kind: kindScalar, AuthRequired: true, InjectUserArg: &idx1},
		"folder_delete":                      {Kind: kindScalar, AuthRequired: true, InjectUserArg: &idx1},
		"folder_remove_video":                {Kind: kindScalar, AuthRequired: true, InjectUserArg: &idx2},
		"folder_set_video_order":             {Kind: kindScalar, AuthRequired: true, InjectUserArg: &idx2},
		"folder_move_video":                  {Kind: kindScalar, AuthRequired: true, InjectUserArg: &idx3},
		"favorites_get_or_create_root":       {Kind: kindScalar, AuthRequired: true, InjectUserArg: &idx0},
		"favorites_add_video":                {Kind: kindScalar, AuthRequired: true, InjectUserArg: &idx0},
		"favorites_remove_video":             {Kind: kindScalar, AuthRequired: true, InjectUserArg: &idx0},
		"favorites_move_video":               {Kind: kindScalar, AuthRequired: true, InjectUserArg: &idx0},
		"favorites_is_video_saved":           {Kind: kindScalar, AuthRequired: true, InjectUserArg: &idx0},
		"video_create_in_library":            {Kind: kindScalar, AuthRequired: true, InjectUserArg: &idx0},
		"video_place_in_library_folder":      {Kind: kindExec, AuthRequired: true, InjectUserArg: &idx0},
		"video_move_between_library_folders": {Kind: kindScalar, AuthRequired: true, InjectUserArg: &idx0},

		// Social
		"video_set_reaction":       {Kind: kindExec, AuthRequired: true, InjectUserArg: &idx1},
		"video_add_comment":        {Kind: kindScalar, AuthRequired: true, InjectUserArg: &idx1},
		"video_delete_comment":     {Kind: kindScalar, AuthRequired: true, InjectUserArg: &idx1},
		"video_record_view":        {Kind: kindExec},
		"video_get_user_reaction":  {Kind: kindScalar},
		"video_list_reactions":     {Kind: kindTableList},
		"video_list_comments":      {Kind: kindTableList},
		"video_get_comment":        {Kind: kindTableOne},
		"video_list_views":         {Kind: kindTableList, AuthRequired: true, InjectUserArg: &idx1},
		"video_get_social_summary": {Kind: kindTableOne},
		"video_remove_reaction":    {Kind: kindScalar, AuthRequired: true, InjectUserArg: &idx1},
		"video_update_comment":     {Kind: kindScalar, AuthRequired: true, InjectUserArg: &idx1},

		// Purchases / tokens
		"purchase_create":                 {Kind: kindScalar, AuthRequired: true, InjectUserArg: &idx0},
		"purchase_set_status":             {Kind: kindExec},
		"download_token_issue":            {Kind: kindTableOne, AuthRequired: true, InjectUserArg: &idx0},
		"download_token_consume":          {Kind: kindScalar},
		"download_tokens_cleanup_expired": {Kind: kindScalar},

		// Transcoding
		"transcode_enqueue":              {Kind: kindScalar},
		"transcode_claim_next":           {Kind: kindTableOne},
		"transcode_finish":               {Kind: kindExec},
		"transcode_set_video_media_info": {Kind: kindScalar},
		"transcode_add_hls_variant":      {Kind: kindScalar},
		"transcode_replace_hls_variants": {Kind: kindScalar},
		"transcode_finalize_video":       {Kind: kindScalar},

		// Feed
		"feed_video_published": {Kind: kindScalar},
		"feed_following":       {Kind: kindTableList, AuthRequired: true, InjectUserArg: &idx0},
		"feed_hot":             {Kind: kindTableList},

		// Stream/download helpers
		"video_get_hls_master_for_viewer":    {Kind: kindTableOne},
		"video_list_hls_variants_for_viewer": {Kind: kindTableList},
		"video_get_download_source_for_user": {Kind: kindScalar, AuthRequired: true, InjectUserArg: &idx0},

		// Additional reads
		"user_get_profile": {Kind: kindTableOne},
		"folder_list_tree": {Kind: kindTableList, AuthRequired: true, InjectUserArg: &idx0},
		"purchase_get":     {Kind: kindTableOne, AuthRequired: true, InjectUserArg: &idx0},
		"purchase_list_my": {Kind: kindTableList, AuthRequired: true, InjectUserArg: &idx0},
	}
}

func (a *app) handleHealth(w http.ResponseWriter, r *http.Request) {
	ctx, cancel := context.WithTimeout(r.Context(), 3*time.Second)
	defer cancel()
	if err := a.db.Ping(ctx); err != nil {
		writeError(w, http.StatusServiceUnavailable, "database unavailable")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"status": "ok"})
}

func (a *app) handleMe(w http.ResponseWriter, r *http.Request) {
	u, ok := getUser(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	writeJSON(w, http.StatusOK, u)
}

func (a *app) handleRPC(w http.ResponseWriter, r *http.Request) {
	name := chi.URLParam(r, "function")
	def, ok := a.fns[name]
	if !ok {
		writeError(w, http.StatusNotFound, "function is not exposed")
		return
	}

	var req rpcRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}

	for i := range req.Args {
		req.Args[i] = normalizeArg(req.Args[i])
	}

	u, hasUser := getUser(r.Context())
	if def.AuthRequired && !hasUser {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	if def.InjectUserArg != nil {
		idx := *def.InjectUserArg
		for len(req.Args) <= idx {
			req.Args = append(req.Args, nil)
		}
		if hasUser {
			req.Args[idx] = u.UserID
		}
	}

	ctx, cancel := context.WithTimeout(r.Context(), 20*time.Second)
	defer cancel()

	callSQL := buildFunctionCallSQL(name, len(req.Args))
	var (
		data json.RawMessage
		err  error
	)

	switch def.Kind {
	case kindScalar:
		data, err = a.scalarAsJSON(ctx, callSQL, req.Args...)
	case kindExec:
		err = a.execFunction(ctx, callSQL, req.Args...)
		data = json.RawMessage(`{"ok":true}`)
	case kindTableList:
		data, err = a.tableListAsJSON(ctx, callSQL, req.Args...)
	case kindTableOne:
		data, err = a.tableOneAsJSON(ctx, callSQL, req.Args...)
		if err == nil && string(data) == "null" {
			writeError(w, http.StatusNotFound, "not found")
			return
		}
	default:
		writeError(w, http.StatusInternalServerError, "unknown function kind")
		return
	}

	if err != nil {
		var pgErr *pgconn.PgError
		if errors.As(err, &pgErr) {
			writeJSON(w, http.StatusBadRequest, map[string]any{
				"error":   "database error",
				"code":    pgErr.Code,
				"message": pgErr.Message,
			})
			return
		}
		writeError(w, http.StatusInternalServerError, "internal error")
		return
	}

	writeJSON(w, http.StatusOK, rpcResponse{
		Function: name,
		Kind:     def.Kind,
		Data:     data,
		OK:       true,
	})
}

type registerRequest struct {
	Email    string `json:"email"`
	Username string `json:"username"`
	Password string `json:"password"`
}

type loginRequest struct {
	Login    string `json:"login"`
	Password string `json:"password"`
}

func (a *app) handleAuthRegister(w http.ResponseWriter, r *http.Request) {
	var req registerRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	req.Email = strings.TrimSpace(req.Email)
	req.Username = strings.TrimSpace(req.Username)
	if req.Email == "" || req.Username == "" || len(req.Password) < 6 {
		writeError(w, http.StatusBadRequest, "email, username and password(min 6) are required")
		return
	}

	hash, err := bcrypt.GenerateFromPassword([]byte(req.Password), bcrypt.DefaultCost)
	if err != nil {
		writeError(w, http.StatusInternalServerError, "cannot hash password")
		return
	}

	var user authUser
	const q = `
		INSERT INTO users(email, username, password_hash, display_name)
		VALUES ($1::citext, $2::citext, $3, $2::text)
		RETURNING id::text, email::text, username::text, COALESCE(display_name,''), COALESCE(avatar_url,''), is_active`
	if err := a.db.QueryRow(r.Context(), q, req.Email, req.Username, string(hash)).Scan(
		&user.UserID, &user.Email, &user.Username, &user.DisplayName, &user.AvatarURL, &user.IsActive,
	); err != nil {
		a.writeDBError(w, err)
		return
	}

	sess, err := a.createSession(r.Context(), user.UserID, r.UserAgent(), clientIP(r), 30*24*time.Hour)
	if err != nil {
		a.writeDBError(w, err)
		return
	}
	a.setSessionCookie(w, sess.Token, sess.ExpiresAt)
	writeJSON(w, http.StatusCreated, map[string]any{"user": user})
}

func (a *app) handleAuthLogin(w http.ResponseWriter, r *http.Request) {
	var req loginRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	login := strings.TrimSpace(req.Login)
	if login == "" || req.Password == "" {
		writeError(w, http.StatusBadRequest, "login and password are required")
		return
	}

	var (
		user         authUser
		passwordHash string
	)
	const q = `
		SELECT id::text, email::text, username::text, COALESCE(display_name,''), COALESCE(avatar_url,''), is_active, COALESCE(password_hash,'')
		FROM users
		WHERE email = $1::citext OR username = $1::citext
		LIMIT 1`
	err := a.db.QueryRow(r.Context(), q, login).Scan(
		&user.UserID, &user.Email, &user.Username, &user.DisplayName, &user.AvatarURL, &user.IsActive, &passwordHash,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		writeError(w, http.StatusUnauthorized, "invalid credentials")
		return
	}
	if err != nil {
		a.writeDBError(w, err)
		return
	}
	if !user.IsActive {
		writeError(w, http.StatusForbidden, "user is inactive")
		return
	}

	// backward compatibility for seeded non-bcrypt hashes
	if strings.HasPrefix(passwordHash, "$2a$") || strings.HasPrefix(passwordHash, "$2b$") || strings.HasPrefix(passwordHash, "$2y$") {
		if err := bcrypt.CompareHashAndPassword([]byte(passwordHash), []byte(req.Password)); err != nil {
			writeError(w, http.StatusUnauthorized, "invalid credentials")
			return
		}
	} else if passwordHash != req.Password {
		writeError(w, http.StatusUnauthorized, "invalid credentials")
		return
	}

	sess, err := a.createSession(r.Context(), user.UserID, r.UserAgent(), clientIP(r), 30*24*time.Hour)
	if err != nil {
		a.writeDBError(w, err)
		return
	}
	a.setSessionCookie(w, sess.Token, sess.ExpiresAt)
	writeJSON(w, http.StatusOK, map[string]any{"user": user})
}

func (a *app) handleAuthLogout(w http.ResponseWriter, r *http.Request) {
	token := extractSessionToken(r)
	if token == "" {
		a.clearSessionCookie(w)
		w.WriteHeader(http.StatusNoContent)
		return
	}
	_, _ = a.callScalar(r.Context(), "auth_delete_session", token)
	a.clearSessionCookie(w)
	w.WriteHeader(http.StatusNoContent)
}

func (a *app) handleGetUserProfile(w http.ResponseWriter, r *http.Request) {
	userID := chi.URLParam(r, "userId")
	var viewerID any
	if u, ok := getUser(r.Context()); ok {
		viewerID = u.UserID
	}
	raw, err := a.callTableOne(r.Context(), "user_get_profile", viewerID, userID)
	if err != nil {
		a.writeDBError(w, err)
		return
	}
	if string(raw) == "null" {
		writeError(w, http.StatusNotFound, "not found")
		return
	}
	writeJSON(w, http.StatusOK, decodeRawAny(raw))
}

func (a *app) handleFollowUser(w http.ResponseWriter, r *http.Request) {
	u, ok := requireUser(w, r)
	if !ok {
		return
	}
	targetID := chi.URLParam(r, "userId")
	raw, err := a.callScalar(r.Context(), "follow_create", u.UserID, targetID)
	if err != nil {
		a.writeDBError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"following": decodeRawAny(raw),
	})
}

func (a *app) handleUnfollowUser(w http.ResponseWriter, r *http.Request) {
	u, ok := requireUser(w, r)
	if !ok {
		return
	}
	targetID := chi.URLParam(r, "userId")
	raw, err := a.callScalar(r.Context(), "follow_delete", u.UserID, targetID)
	if err != nil {
		a.writeDBError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"following": false,
		"deleted":   decodeRawAny(raw),
	})
}

func (a *app) handleListMyFollowing(w http.ResponseWriter, r *http.Request) {
	u, ok := requireUser(w, r)
	if !ok {
		return
	}
	args := []any{
		u.UserID,
		queryIntDefault(r, "limit", 50),
		queryStringOrNil(r, "cursorCreatedAt"),
		queryStringOrNil(r, "cursorUserId"),
	}
	raw, err := a.callTableList(r.Context(), "follow_list_following", args...)
	if err != nil {
		a.writeDBError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": decodeRawAny(raw)})
}

func (a *app) handleListMyFollowers(w http.ResponseWriter, r *http.Request) {
	u, ok := requireUser(w, r)
	if !ok {
		return
	}
	args := []any{
		u.UserID,
		queryIntDefault(r, "limit", 50),
		queryStringOrNil(r, "cursorCreatedAt"),
		queryStringOrNil(r, "cursorUserId"),
	}
	raw, err := a.callTableList(r.Context(), "follow_list_followers", args...)
	if err != nil {
		a.writeDBError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": decodeRawAny(raw)})
}

func (a *app) handleListMyFolders(w http.ResponseWriter, r *http.Request) {
	u, ok := requireUser(w, r)
	if !ok {
		return
	}
	folderType := strings.TrimSpace(r.URL.Query().Get("type"))
	if folderType == "" {
		writeError(w, http.StatusBadRequest, "type is required")
		return
	}
	args := []any{
		u.UserID,
		folderType,
		queryStringOrNil(r, "parentId"),
		queryIntDefault(r, "limit", 50),
		queryStringOrNil(r, "cursorCreatedAt"),
		queryStringOrNil(r, "cursorFolderId"),
	}
	raw, err := a.callTableList(r.Context(), "folder_list_children", args...)
	if err != nil {
		a.writeDBError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": decodeRawAny(raw)})
}

func (a *app) handleListMyFolderTree(w http.ResponseWriter, r *http.Request) {
	u, ok := requireUser(w, r)
	if !ok {
		return
	}
	folderType := strings.TrimSpace(r.URL.Query().Get("type"))
	if folderType == "" {
		writeError(w, http.StatusBadRequest, "type is required")
		return
	}
	raw, err := a.callTableList(r.Context(), "folder_list_tree", u.UserID, folderType)
	if err != nil {
		a.writeDBError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": decodeRawAny(raw)})
}

type createFolderRequest struct {
	Type     string  `json:"type"`
	Name     string  `json:"name"`
	ParentID *string `json:"parentId"`
}

func (a *app) handleCreateMyFolder(w http.ResponseWriter, r *http.Request) {
	u, ok := requireUser(w, r)
	if !ok {
		return
	}
	var req createFolderRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	raw, err := a.callScalar(r.Context(), "folder_create", u.UserID, req.Type, nilIfPtr(req.ParentID), req.Name)
	if err != nil {
		a.writeDBError(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{"folderId": decodeRawAny(raw)})
}

func (a *app) handleGetMyFolder(w http.ResponseWriter, r *http.Request) {
	u, ok := requireUser(w, r)
	if !ok {
		return
	}
	raw, err := a.callTableOne(r.Context(), "folder_get", chi.URLParam(r, "folderId"), u.UserID)
	if err != nil {
		a.writeDBError(w, err)
		return
	}
	if string(raw) == "null" {
		writeError(w, http.StatusNotFound, "not found")
		return
	}
	writeJSON(w, http.StatusOK, decodeRawAny(raw))
}

type patchFolderRequest struct {
	Name     *string `json:"name"`
	ParentID *string `json:"parentId"`
}

func (a *app) handlePatchMyFolder(w http.ResponseWriter, r *http.Request) {
	u, ok := requireUser(w, r)
	if !ok {
		return
	}
	folderID := chi.URLParam(r, "folderId")
	var req patchFolderRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	if req.Name == nil && req.ParentID == nil {
		writeError(w, http.StatusBadRequest, "nothing to update")
		return
	}
	if req.Name != nil {
		if _, err := a.callScalar(r.Context(), "folder_rename", folderID, u.UserID, *req.Name); err != nil {
			a.writeDBError(w, err)
			return
		}
	}
	if req.ParentID != nil {
		if _, err := a.callScalar(r.Context(), "folder_move", folderID, u.UserID, nilIfPtr(req.ParentID)); err != nil {
			a.writeDBError(w, err)
			return
		}
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true})
}

func (a *app) handleDeleteMyFolder(w http.ResponseWriter, r *http.Request) {
	u, ok := requireUser(w, r)
	if !ok {
		return
	}
	raw, err := a.callScalar(r.Context(), "folder_delete", chi.URLParam(r, "folderId"), u.UserID)
	if err != nil {
		a.writeDBError(w, err)
		return
	}
	if isJSONBoolFalse(raw) {
		writeError(w, http.StatusNotFound, "not found")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (a *app) handleListMyFolderVideos(w http.ResponseWriter, r *http.Request) {
	u, ok := requireUser(w, r)
	if !ok {
		return
	}
	args := []any{
		chi.URLParam(r, "folderId"),
		u.UserID,
		queryIntDefault(r, "limit", 50),
		queryIntOrNil(r, "cursorOrderIndex"),
		queryStringOrNil(r, "cursorAddedAt"),
		queryStringOrNil(r, "cursorVideoId"),
	}
	raw, err := a.callTableList(r.Context(), "folder_list_videos", args...)
	if err != nil {
		a.writeDBError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": decodeRawAny(raw)})
}

type addFolderVideoRequest struct {
	VideoID    string `json:"videoId"`
	OrderIndex *int   `json:"orderIndex"`
}

func (a *app) handleAddVideoToMyFolder(w http.ResponseWriter, r *http.Request) {
	u, ok := requireUser(w, r)
	if !ok {
		return
	}
	folderID := chi.URLParam(r, "folderId")
	var req addFolderVideoRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	if strings.TrimSpace(req.VideoID) == "" {
		writeError(w, http.StatusBadRequest, "videoId is required")
		return
	}
	if err := a.callExec(r.Context(), "folder_add_video", folderID, req.VideoID, u.UserID, req.OrderIndex); err != nil {
		a.writeDBError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true})
}

func (a *app) handleRemoveVideoFromMyFolder(w http.ResponseWriter, r *http.Request) {
	u, ok := requireUser(w, r)
	if !ok {
		return
	}
	raw, err := a.callScalar(
		r.Context(),
		"folder_remove_video",
		chi.URLParam(r, "folderId"),
		chi.URLParam(r, "videoId"),
		u.UserID,
	)
	if err != nil {
		a.writeDBError(w, err)
		return
	}
	if isJSONBoolFalse(raw) {
		writeError(w, http.StatusNotFound, "not found")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

type moveVideoRequest struct {
	ToFolderID   string `json:"toFolderId"`
	ToOrderIndex *int   `json:"toOrderIndex"`
}

func (a *app) handleMoveVideoBetweenMyFolders(w http.ResponseWriter, r *http.Request) {
	u, ok := requireUser(w, r)
	if !ok {
		return
	}
	var req moveVideoRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	if strings.TrimSpace(req.ToFolderID) == "" {
		writeError(w, http.StatusBadRequest, "toFolderId is required")
		return
	}
	raw, err := a.callScalar(
		r.Context(),
		"folder_move_video",
		chi.URLParam(r, "folderId"),
		req.ToFolderID,
		chi.URLParam(r, "videoId"),
		u.UserID,
		req.ToOrderIndex,
	)
	if err != nil {
		a.writeDBError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"moved": decodeRawAny(raw)})
}

type createVideoRequest struct {
	Title       string   `json:"title"`
	Description *string  `json:"description"`
	Visibility  string   `json:"visibility"`
	FolderIDs   []string `json:"folderIds"`
}

func (a *app) handleCreateVideo(w http.ResponseWriter, r *http.Request) {
	u, ok := requireUser(w, r)
	if !ok {
		return
	}
	var req createVideoRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	videoRaw, err := a.callScalar(r.Context(), "video_create", u.UserID, req.Title, req.Description, req.Visibility, nil, nil, nil, nil, nil)
	if err != nil {
		a.writeDBError(w, err)
		return
	}
	videoID, ok := decodeRawAny(videoRaw).(string)
	if !ok || strings.TrimSpace(videoID) == "" {
		writeError(w, http.StatusInternalServerError, "invalid video id")
		return
	}
	for _, fid := range req.FolderIDs {
		if strings.TrimSpace(fid) == "" {
			continue
		}
		if err := a.callExec(r.Context(), "folder_add_video", fid, videoID, u.UserID, nil); err != nil {
			a.writeDBError(w, err)
			return
		}
	}
	writeJSON(w, http.StatusCreated, map[string]any{"videoId": videoID})
}

func (a *app) handleGetVideo(w http.ResponseWriter, r *http.Request) {
	videoID := chi.URLParam(r, "videoId")
	var viewerID any
	if u, ok := getUser(r.Context()); ok {
		viewerID = u.UserID
	}
	raw, err := a.callTableOne(r.Context(), "video_get", viewerID, videoID)
	if err != nil {
		a.writeDBError(w, err)
		return
	}
	if string(raw) == "null" {
		writeError(w, http.StatusNotFound, "not found")
		return
	}
	writeJSON(w, http.StatusOK, decodeRawAny(raw))
}

type patchVideoRequest struct {
	Title       *string `json:"title"`
	Description *string `json:"description"`
	Visibility  *string `json:"visibility"`
}

func (a *app) handlePatchVideo(w http.ResponseWriter, r *http.Request) {
	u, ok := requireUser(w, r)
	if !ok {
		return
	}
	var req patchVideoRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	raw, err := a.callScalar(
		r.Context(),
		"video_update_metadata",
		u.UserID,
		chi.URLParam(r, "videoId"),
		req.Title,
		req.Description,
		req.Visibility,
	)
	if err != nil {
		a.writeDBError(w, err)
		return
	}
	if isJSONBoolFalse(raw) {
		writeError(w, http.StatusNotFound, "not found")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true})
}

func (a *app) handleDeleteVideo(w http.ResponseWriter, r *http.Request) {
	u, ok := requireUser(w, r)
	if !ok {
		return
	}
	raw, err := a.callScalar(r.Context(), "video_delete", u.UserID, chi.URLParam(r, "videoId"))
	if err != nil {
		a.writeDBError(w, err)
		return
	}
	if isJSONBoolFalse(raw) {
		writeError(w, http.StatusNotFound, "not found")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (a *app) handlePublishVideo(w http.ResponseWriter, r *http.Request) {
	u, ok := requireUser(w, r)
	if !ok {
		return
	}
	raw, err := a.callScalar(r.Context(), "video_publish", u.UserID, chi.URLParam(r, "videoId"))
	if err != nil {
		a.writeDBError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"published": decodeRawAny(raw)})
}

func (a *app) handleUnpublishVideo(w http.ResponseWriter, r *http.Request) {
	u, ok := requireUser(w, r)
	if !ok {
		return
	}
	raw, err := a.callScalar(r.Context(), "video_unpublish", u.UserID, chi.URLParam(r, "videoId"))
	if err != nil {
		a.writeDBError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"unpublished": decodeRawAny(raw)})
}

func (a *app) handleListMyVideos(w http.ResponseWriter, r *http.Request) {
	u, ok := requireUser(w, r)
	if !ok {
		return
	}
	raw, err := a.callTableList(
		r.Context(),
		"video_list_owner",
		u.UserID,
		queryIntDefault(r, "limit", 50),
		queryIntDefault(r, "offset", 0),
	)
	if err != nil {
		a.writeDBError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": decodeRawAny(raw)})
}

func (a *app) handleListUserVideos(w http.ResponseWriter, r *http.Request) {
	var viewerID any
	if u, ok := getUser(r.Context()); ok {
		viewerID = u.UserID
	}
	raw, err := a.callTableList(
		r.Context(),
		"video_list_user_visible",
		viewerID,
		chi.URLParam(r, "userId"),
		queryIntDefault(r, "limit", 50),
		queryIntDefault(r, "offset", 0),
	)
	if err != nil {
		a.writeDBError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": decodeRawAny(raw)})
}

type putReactionRequest struct {
	Value string `json:"value"`
}

func (a *app) handlePutVideoReaction(w http.ResponseWriter, r *http.Request) {
	u, ok := requireUser(w, r)
	if !ok {
		return
	}
	videoID := chi.URLParam(r, "videoId")
	var req putReactionRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	switch req.Value {
	case "like", "dislike":
		if err := a.callExec(r.Context(), "video_set_reaction", videoID, u.UserID, req.Value); err != nil {
			a.writeDBError(w, err)
			return
		}
	case "none":
		if _, err := a.callScalar(r.Context(), "video_remove_reaction", videoID, u.UserID); err != nil {
			a.writeDBError(w, err)
			return
		}
	default:
		writeError(w, http.StatusBadRequest, "value must be like|dislike|none")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true})
}

func (a *app) handleGetVideoReaction(w http.ResponseWriter, r *http.Request) {
	videoID := chi.URLParam(r, "videoId")
	var viewerID any
	if u, ok := getUser(r.Context()); ok {
		viewerID = u.UserID
	}
	myRaw, err := a.callScalar(r.Context(), "video_get_user_reaction", videoID, viewerID)
	if err != nil {
		a.writeDBError(w, err)
		return
	}
	summaryRaw, err := a.callTableOne(r.Context(), "video_get_social_summary", videoID, viewerID)
	if err != nil {
		a.writeDBError(w, err)
		return
	}
	if string(summaryRaw) == "null" {
		writeError(w, http.StatusNotFound, "not found")
		return
	}
	summary, _ := decodeRawAny(summaryRaw).(map[string]any)
	writeJSON(w, http.StatusOK, map[string]any{
		"myReaction": decodeRawAny(myRaw),
		"likes":      summary["likes_count"],
		"dislikes":   summary["dislikes_count"],
	})
}

func (a *app) handleListVideoComments(w http.ResponseWriter, r *http.Request) {
	videoID := chi.URLParam(r, "videoId")
	var viewerID any
	if u, ok := getUser(r.Context()); ok {
		viewerID = u.UserID
	}
	raw, err := a.callTableList(
		r.Context(),
		"video_list_comments",
		videoID,
		viewerID,
		false,
		queryIntDefault(r, "limit", 50),
		queryStringOrNil(r, "cursorCreatedAt"),
		queryStringOrNil(r, "cursorCommentId"),
	)
	if err != nil {
		a.writeDBError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": decodeRawAny(raw)})
}

type createCommentRequest struct {
	Text string `json:"text"`
}

func (a *app) handleCreateVideoComment(w http.ResponseWriter, r *http.Request) {
	u, ok := requireUser(w, r)
	if !ok {
		return
	}
	var req createCommentRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	raw, err := a.callScalar(r.Context(), "video_add_comment", chi.URLParam(r, "videoId"), u.UserID, req.Text)
	if err != nil {
		a.writeDBError(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{"commentId": decodeRawAny(raw)})
}

type patchCommentRequest struct {
	Text string `json:"text"`
}

func (a *app) handlePatchVideoComment(w http.ResponseWriter, r *http.Request) {
	u, ok := requireUser(w, r)
	if !ok {
		return
	}
	var req patchCommentRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	raw, err := a.callScalar(r.Context(), "video_update_comment", chi.URLParam(r, "commentId"), u.UserID, req.Text)
	if err != nil {
		a.writeDBError(w, err)
		return
	}
	if isJSONBoolFalse(raw) {
		writeError(w, http.StatusNotFound, "not found")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true})
}

func (a *app) handleDeleteVideoComment(w http.ResponseWriter, r *http.Request) {
	u, ok := requireUser(w, r)
	if !ok {
		return
	}
	raw, err := a.callScalar(r.Context(), "video_delete_comment", chi.URLParam(r, "commentId"), u.UserID)
	if err != nil {
		a.writeDBError(w, err)
		return
	}
	if isJSONBoolFalse(raw) {
		writeError(w, http.StatusNotFound, "not found")
		return
	}
	w.WriteHeader(http.StatusNoContent)
}

func (a *app) handleListMyFavorites(w http.ResponseWriter, r *http.Request) {
	u, ok := requireUser(w, r)
	if !ok {
		return
	}
	folderID := strings.TrimSpace(r.URL.Query().Get("folderId"))
	var (
		raw json.RawMessage
		err error
	)
	if folderID == "" {
		raw, err = a.callTableList(
			r.Context(),
			"favorites_list_videos",
			u.UserID,
			queryIntDefault(r, "limit", 50),
			queryStringOrNil(r, "cursorAddedAt"),
			queryStringOrNil(r, "cursorVideoId"),
		)
	} else {
		raw, err = a.callTableList(
			r.Context(),
			"folder_list_videos",
			folderID,
			u.UserID,
			queryIntDefault(r, "limit", 50),
			nil,
			queryStringOrNil(r, "cursorAddedAt"),
			queryStringOrNil(r, "cursorVideoId"),
		)
	}
	if err != nil {
		a.writeDBError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": decodeRawAny(raw)})
}

type putFavoriteRequest struct {
	FolderID   *string `json:"folderId"`
	OrderIndex *int    `json:"orderIndex"`
}

func (a *app) handlePutFavorite(w http.ResponseWriter, r *http.Request) {
	u, ok := requireUser(w, r)
	if !ok {
		return
	}
	videoID := chi.URLParam(r, "videoId")
	var req putFavoriteRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	raw, err := a.callScalar(r.Context(), "favorites_add_video", u.UserID, videoID, nilIfPtr(req.FolderID), req.OrderIndex)
	if err != nil {
		a.writeDBError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"saved":    true,
		"folderId": decodeRawAny(raw),
	})
}

func (a *app) handleDeleteFavorite(w http.ResponseWriter, r *http.Request) {
	u, ok := requireUser(w, r)
	if !ok {
		return
	}
	videoID := chi.URLParam(r, "videoId")
	raw, err := a.callScalar(r.Context(), "favorites_remove_video", u.UserID, videoID, queryStringOrNil(r, "folderId"))
	if err != nil {
		a.writeDBError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"removedCount": decodeRawAny(raw),
	})
}

func (a *app) handleGetFavoriteState(w http.ResponseWriter, r *http.Request) {
	u, ok := requireUser(w, r)
	if !ok {
		return
	}
	videoID := chi.URLParam(r, "videoId")
	raw, err := a.callScalar(r.Context(), "favorites_is_video_saved", u.UserID, videoID)
	if err != nil {
		a.writeDBError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"saved": decodeRawAny(raw)})
}

type purchaseDownloadRequest struct {
	Provider          string `json:"provider"`
	ProviderPaymentID string `json:"providerPaymentId"`
	AmountCents       int    `json:"amountCents"`
	Currency          string `json:"currency"`
}

func (a *app) handleCreatePurchaseDownload(w http.ResponseWriter, r *http.Request) {
	u, ok := requireUser(w, r)
	if !ok {
		return
	}
	videoID := chi.URLParam(r, "videoId")
	var req purchaseDownloadRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	raw, err := a.callScalar(
		r.Context(),
		"purchase_create",
		u.UserID,
		videoID,
		req.AmountCents,
		req.Currency,
		req.Provider,
		req.ProviderPaymentID,
	)
	if err != nil {
		a.writeDBError(w, err)
		return
	}
	writeJSON(w, http.StatusCreated, map[string]any{"purchaseId": decodeRawAny(raw)})
}

func (a *app) handleListMyPurchases(w http.ResponseWriter, r *http.Request) {
	u, ok := requireUser(w, r)
	if !ok {
		return
	}
	raw, err := a.callTableList(
		r.Context(),
		"purchase_list_my",
		u.UserID,
		queryStringOrNil(r, "status"),
		queryIntDefault(r, "limit", 50),
		queryIntDefault(r, "offset", 0),
	)
	if err != nil {
		a.writeDBError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": decodeRawAny(raw)})
}

func (a *app) handleGetMyPurchase(w http.ResponseWriter, r *http.Request) {
	u, ok := requireUser(w, r)
	if !ok {
		return
	}
	raw, err := a.callTableOne(r.Context(), "purchase_get", u.UserID, chi.URLParam(r, "purchaseId"))
	if err != nil {
		a.writeDBError(w, err)
		return
	}
	if string(raw) == "null" {
		writeError(w, http.StatusNotFound, "not found")
		return
	}
	writeJSON(w, http.StatusOK, decodeRawAny(raw))
}

type issueTokenRequest struct {
	PurchaseID *string `json:"purchaseId"`
	TTL        *string `json:"ttl"`
}

func (a *app) handleIssueDownloadToken(w http.ResponseWriter, r *http.Request) {
	u, ok := requireUser(w, r)
	if !ok {
		return
	}
	videoID := chi.URLParam(r, "videoId")
	var req issueTokenRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	var ttl any
	if req.TTL != nil && strings.TrimSpace(*req.TTL) != "" {
		ttl = *req.TTL
	}
	raw, err := a.callTableOne(r.Context(), "download_token_issue", u.UserID, videoID, nilIfPtr(req.PurchaseID), ttl)
	if err != nil {
		a.writeDBError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, decodeRawAny(raw))
}

func (a *app) handleFeedFollowing(w http.ResponseWriter, r *http.Request) {
	u, ok := requireUser(w, r)
	if !ok {
		return
	}
	raw, err := a.callTableList(
		r.Context(),
		"feed_following",
		u.UserID,
		queryIntDefault(r, "limit", 50),
		queryIntDefault(r, "offset", 0),
	)
	if err != nil {
		a.writeDBError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": decodeRawAny(raw)})
}

func (a *app) handleFeedHot(w http.ResponseWriter, r *http.Request) {
	var viewerID any
	if u, ok := getUser(r.Context()); ok {
		viewerID = u.UserID
	}
	window := queryStringDefault(r, "window", "48 hours")
	raw, err := a.callTableList(
		r.Context(),
		"feed_hot",
		viewerID,
		queryIntDefault(r, "limit", 50),
		queryIntDefault(r, "offset", 0),
		window,
	)
	if err != nil {
		a.writeDBError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": decodeRawAny(raw)})
}

func (a *app) handleFeedCombined(w http.ResponseWriter, r *http.Request) {
	var viewerID any
	var hasUser bool
	if u, ok := getUser(r.Context()); ok {
		viewerID = u.UserID
		hasUser = true
	}
	limit := queryIntDefault(r, "limit", 50)
	offset := queryIntDefault(r, "offset", 0)
	window := queryStringDefault(r, "window", "48 hours")

	hotRaw, err := a.callTableList(r.Context(), "feed_hot", viewerID, limit, offset, window)
	if err != nil {
		a.writeDBError(w, err)
		return
	}
	hotItems := decodeRawSliceMap(hotRaw)
	followingItems := []map[string]any{}
	if hasUser {
		followRaw, err := a.callTableList(r.Context(), "feed_following", viewerID, limit, offset)
		if err != nil {
			a.writeDBError(w, err)
			return
		}
		followingItems = decodeRawSliceMap(followRaw)
	}

	seen := make(map[string]struct{}, len(hotItems)+len(followingItems))
	items := make([]map[string]any, 0, len(hotItems)+len(followingItems))
	for _, it := range followingItems {
		key := fmt.Sprint(it["video_id"])
		if _, exists := seen[key]; exists {
			continue
		}
		seen[key] = struct{}{}
		it["source"] = "following"
		items = append(items, it)
	}
	for _, it := range hotItems {
		key := fmt.Sprint(it["video_id"])
		if _, exists := seen[key]; exists {
			continue
		}
		seen[key] = struct{}{}
		it["source"] = "hot"
		items = append(items, it)
	}

	writeJSON(w, http.StatusOK, map[string]any{"items": items})
}

func (a *app) handleGetVideoPlayback(w http.ResponseWriter, r *http.Request) {
	videoID := chi.URLParam(r, "videoId")
	var viewerID any
	if u, ok := getUser(r.Context()); ok {
		viewerID = u.UserID
	}
	raw, err := a.callTableOne(r.Context(), "video_get_hls_master_for_viewer", viewerID, videoID)
	if err != nil {
		a.writeDBError(w, err)
		return
	}
	if string(raw) == "null" {
		writeError(w, http.StatusNotFound, "not found")
		return
	}
	obj, _ := decodeRawAny(raw).(map[string]any)
	masterName := "master.m3u8"
	if v, ok := obj["hls_master_key"].(string); ok && strings.TrimSpace(v) != "" {
		masterName = path.Base(v)
	}
	writeJSON(w, http.StatusOK, map[string]any{
		"type":        "hls",
		"manifestUrl": fmt.Sprintf("/stream/hls/%s/%s", videoID, masterName),
		"meta":        obj,
	})
}

func (a *app) handleListVideoReactions(w http.ResponseWriter, r *http.Request) {
	videoID := chi.URLParam(r, "videoId")
	var viewerID any
	if u, ok := getUser(r.Context()); ok {
		viewerID = u.UserID
	}
	raw, err := a.callTableList(
		r.Context(),
		"video_list_reactions",
		videoID,
		viewerID,
		queryStringOrNil(r, "value"),
		queryIntDefault(r, "limit", 50),
		queryStringOrNil(r, "cursorCreatedAt"),
		queryStringOrNil(r, "cursorUserId"),
	)
	if err != nil {
		a.writeDBError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"items": decodeRawAny(raw)})
}

func (a *app) handleGetVideoDownload(w http.ResponseWriter, r *http.Request) {
	u, ok := requireUser(w, r)
	if !ok {
		return
	}
	videoID := chi.URLParam(r, "videoId")
	if token := strings.TrimSpace(r.URL.Query().Get("token")); token != "" {
		consumed, err := a.callScalar(r.Context(), "download_token_consume", token)
		if err != nil {
			a.writeDBError(w, err)
			return
		}
		got, _ := decodeRawAny(consumed).(string)
		if got == "" || got != videoID {
			writeError(w, http.StatusForbidden, "invalid or expired token")
			return
		}
	}

	raw, err := a.callScalar(r.Context(), "video_get_download_source_for_user", u.UserID, videoID)
	if err != nil {
		a.writeDBError(w, err)
		return
	}
	key, _ := decodeRawAny(raw).(string)
	if strings.TrimSpace(key) == "" {
		writeError(w, http.StatusForbidden, "no download rights")
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"sourceKey": key})
}

type purchaseStatusRequest struct {
	Status string `json:"status"`
}

func (a *app) handleSetPurchaseStatus(w http.ResponseWriter, r *http.Request) {
	if !a.requireInternal(w, r) {
		return
	}
	var req purchaseStatusRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	if strings.TrimSpace(req.Status) == "" {
		writeError(w, http.StatusBadRequest, "status is required")
		return
	}
	if err := a.callExec(r.Context(), "purchase_set_status", chi.URLParam(r, "purchaseId"), req.Status); err != nil {
		a.writeDBError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true})
}

type transcodeEnqueueRequest struct {
	VideoID  string `json:"videoId"`
	Priority *int   `json:"priority"`
}

func (a *app) handleInternalTranscodeEnqueue(w http.ResponseWriter, r *http.Request) {
	if !a.requireInternal(w, r) {
		return
	}
	var req transcodeEnqueueRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	priority := 100
	if req.Priority != nil {
		priority = *req.Priority
	}
	raw, err := a.callScalar(r.Context(), "transcode_enqueue", req.VideoID, priority)
	if err != nil {
		a.writeDBError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"jobId": decodeRawAny(raw)})
}

type transcodeClaimRequest struct {
	WorkerID string `json:"workerId"`
}

func (a *app) handleInternalTranscodeClaim(w http.ResponseWriter, r *http.Request) {
	if !a.requireInternal(w, r) {
		return
	}
	var req transcodeClaimRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	raw, err := a.callTableOne(r.Context(), "transcode_claim_next", req.WorkerID)
	if err != nil {
		a.writeDBError(w, err)
		return
	}
	if string(raw) == "null" {
		writeJSON(w, http.StatusOK, map[string]any{"job": nil})
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"job": decodeRawAny(raw)})
}

type transcodeFinishRequest struct {
	JobID        string  `json:"jobId"`
	Status       string  `json:"status"`
	ErrorMessage *string `json:"errorMessage"`
	HLSMasterKey *string `json:"hlsMasterKey"`
	PosterKey    *string `json:"posterKey"`
}

func (a *app) handleInternalTranscodeFinish(w http.ResponseWriter, r *http.Request) {
	if !a.requireInternal(w, r) {
		return
	}
	var req transcodeFinishRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	if err := a.callExec(r.Context(), "transcode_finish", req.JobID, req.Status, nilIfPtr(req.ErrorMessage), nilIfPtr(req.HLSMasterKey), nilIfPtr(req.PosterKey)); err != nil {
		a.writeDBError(w, err)
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true})
}

type transcodeAssetsRequest struct {
	VideoID         string          `json:"videoId"`
	DurationSeconds *int            `json:"durationSeconds"`
	Width           *int            `json:"width"`
	Height          *int            `json:"height"`
	SourceSizeBytes *int64          `json:"sourceSizeBytes"`
	Variants        json.RawMessage `json:"variants"`
	HLSMasterKey    *string         `json:"hlsMasterKey"`
	PosterKey       *string         `json:"posterKey"`
}

func (a *app) handleInternalTranscodeAssets(w http.ResponseWriter, r *http.Request) {
	if !a.requireInternal(w, r) {
		return
	}
	var req transcodeAssetsRequest
	if err := decodeJSON(r, &req); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	if strings.TrimSpace(req.VideoID) == "" {
		writeError(w, http.StatusBadRequest, "videoId is required")
		return
	}
	_, err := a.callScalar(
		r.Context(),
		"transcode_set_video_media_info",
		req.VideoID,
		req.DurationSeconds,
		req.Width,
		req.Height,
		req.SourceSizeBytes,
	)
	if err != nil {
		a.writeDBError(w, err)
		return
	}
	if len(req.Variants) > 0 && string(req.Variants) != "null" {
		const q = "SELECT to_jsonb(x) FROM (SELECT transcode_replace_hls_variants($1, $2::jsonb) AS x) t"
		var raw []byte
		if err := a.db.QueryRow(r.Context(), q, req.VideoID, string(req.Variants)).Scan(&raw); err != nil {
			a.writeDBError(w, err)
			return
		}
	}
	if req.HLSMasterKey != nil && strings.TrimSpace(*req.HLSMasterKey) != "" {
		_, err := a.callScalar(
			r.Context(),
			"transcode_finalize_video",
			req.VideoID,
			*req.HLSMasterKey,
			nilIfPtr(req.PosterKey),
			req.DurationSeconds,
			req.Width,
			req.Height,
		)
		if err != nil {
			a.writeDBError(w, err)
			return
		}
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true})
}

func (a *app) handleStreamHLS(w http.ResponseWriter, r *http.Request) {
	videoID := chi.URLParam(r, "videoId")
	filePart := strings.TrimSpace(chi.URLParam(r, "*"))
	if filePart == "" {
		writeError(w, http.StatusNotFound, "not found")
		return
	}
	var viewerID any
	if u, ok := getUser(r.Context()); ok {
		viewerID = u.UserID
	}
	raw, err := a.callTableOne(r.Context(), "video_get_hls_master_for_viewer", viewerID, videoID)
	if err != nil {
		a.writeDBError(w, err)
		return
	}
	if string(raw) == "null" {
		writeError(w, http.StatusForbidden, "forbidden")
		return
	}
	obj, _ := decodeRawAny(raw).(map[string]any)
	masterKey, _ := obj["hls_master_key"].(string)
	if strings.TrimSpace(masterKey) == "" {
		writeError(w, http.StatusNotFound, "not found")
		return
	}
	baseDir := path.Dir(masterKey)
	cleanedPart := path.Clean("/" + filePart)
	if strings.HasPrefix(cleanedPart, "/../") || cleanedPart == "/.." {
		writeError(w, http.StatusBadRequest, "invalid path")
		return
	}
	relativePart := strings.TrimPrefix(cleanedPart, "/")
	key := path.Clean(path.Join(baseDir, relativePart))
	if !strings.HasPrefix(key, baseDir) {
		writeError(w, http.StatusBadRequest, "invalid path")
		return
	}
	fsPath := filepath.Join(a.storageRoot, filepath.FromSlash(key))
	if strings.HasSuffix(strings.ToLower(fsPath), ".m3u8") {
		w.Header().Set("Content-Type", "application/vnd.apple.mpegurl")
	} else if strings.HasSuffix(strings.ToLower(fsPath), ".ts") {
		w.Header().Set("Content-Type", "video/mp2t")
	}
	http.ServeFile(w, r, fsPath)
}

func (a *app) optionalAuth(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		token := extractSessionToken(r)
		if token == "" {
			next.ServeHTTP(w, r)
			return
		}

		ctx, cancel := context.WithTimeout(r.Context(), 5*time.Second)
		defer cancel()

		u, err := a.fetchUserBySession(ctx, token)
		if err != nil {
			next.ServeHTTP(w, r)
			return
		}
		if u != nil {
			r = r.WithContext(context.WithValue(r.Context(), userContextKey, *u))
		}
		next.ServeHTTP(w, r)
	})
}

func (a *app) fetchUserBySession(ctx context.Context, token string) (*authUser, error) {
	const q = `
		SELECT user_id::text, email::text, username::text,
		       COALESCE(display_name, ''), COALESCE(avatar_url, ''), is_active
		FROM auth_get_user_by_session($1)
		LIMIT 1`

	var u authUser
	err := a.db.QueryRow(ctx, q, token).Scan(
		&u.UserID,
		&u.Email,
		&u.Username,
		&u.DisplayName,
		&u.AvatarURL,
		&u.IsActive,
	)
	if errors.Is(err, pgx.ErrNoRows) {
		return nil, nil
	}
	if err != nil {
		return nil, err
	}
	return &u, nil
}

type createdSession struct {
	Token     string
	ExpiresAt time.Time
}

func (a *app) createSession(ctx context.Context, userID, userAgent, ip string, ttl time.Duration) (*createdSession, error) {
	const q = `
		SELECT session_token, expires_at
		FROM auth_create_session($1::uuid, $2, $3::inet, $4::interval)
		LIMIT 1`
	var s createdSession
	if err := a.db.QueryRow(ctx, q, userID, userAgent, ip, ttl.String()).Scan(&s.Token, &s.ExpiresAt); err != nil {
		return nil, err
	}
	return &s, nil
}

func (a *app) setSessionCookie(w http.ResponseWriter, token string, expiresAt time.Time) {
	http.SetCookie(w, &http.Cookie{
		Name:     "session_token",
		Value:    token,
		Path:     "/",
		HttpOnly: true,
		Secure:   a.cookieSecure,
		SameSite: http.SameSiteLaxMode,
		Expires:  expiresAt,
	})
}

func (a *app) clearSessionCookie(w http.ResponseWriter) {
	http.SetCookie(w, &http.Cookie{
		Name:     "session_token",
		Value:    "",
		Path:     "/",
		HttpOnly: true,
		Secure:   a.cookieSecure,
		SameSite: http.SameSiteLaxMode,
		MaxAge:   -1,
		Expires:  time.Unix(0, 0),
	})
}

func (a *app) requireInternal(w http.ResponseWriter, r *http.Request) bool {
	if a.internalAuth == "" {
		return true
	}
	got := strings.TrimSpace(r.Header.Get("X-Internal-Token"))
	if got == "" || got != a.internalAuth {
		writeError(w, http.StatusUnauthorized, "internal auth failed")
		return false
	}
	return true
}

func (a *app) callScalar(ctx context.Context, name string, args ...any) (json.RawMessage, error) {
	callCtx, cancel := context.WithTimeout(ctx, 20*time.Second)
	defer cancel()
	return a.scalarAsJSON(callCtx, buildFunctionCallSQL(name, len(args)), args...)
}

func (a *app) callExec(ctx context.Context, name string, args ...any) error {
	callCtx, cancel := context.WithTimeout(ctx, 20*time.Second)
	defer cancel()
	return a.execFunction(callCtx, buildFunctionCallSQL(name, len(args)), args...)
}

func (a *app) callTableList(ctx context.Context, name string, args ...any) (json.RawMessage, error) {
	callCtx, cancel := context.WithTimeout(ctx, 20*time.Second)
	defer cancel()
	return a.tableListAsJSON(callCtx, buildFunctionCallSQL(name, len(args)), args...)
}

func (a *app) callTableOne(ctx context.Context, name string, args ...any) (json.RawMessage, error) {
	callCtx, cancel := context.WithTimeout(ctx, 20*time.Second)
	defer cancel()
	return a.tableOneAsJSON(callCtx, buildFunctionCallSQL(name, len(args)), args...)
}

func (a *app) writeDBError(w http.ResponseWriter, err error) {
	var pgErr *pgconn.PgError
	if errors.As(err, &pgErr) {
		status := http.StatusBadRequest
		if pgErr.Code == "23505" {
			status = http.StatusConflict
		}
		writeJSON(w, status, map[string]any{
			"error":   "database error",
			"code":    pgErr.Code,
			"message": pgErr.Message,
			"ok":      false,
		})
		return
	}
	writeError(w, http.StatusInternalServerError, "internal error")
}

func (a *app) scalarAsJSON(ctx context.Context, callSQL string, args ...any) (json.RawMessage, error) {
	q := "SELECT to_jsonb(x) FROM (SELECT " + callSQL + " AS x) t"
	var raw []byte
	if err := a.db.QueryRow(ctx, q, args...).Scan(&raw); err != nil {
		return nil, err
	}
	if raw == nil {
		return json.RawMessage("null"), nil
	}
	return json.RawMessage(raw), nil
}

func (a *app) execFunction(ctx context.Context, callSQL string, args ...any) error {
	q := "SELECT " + callSQL
	_, err := a.db.Exec(ctx, q, args...)
	return err
}

func (a *app) tableListAsJSON(ctx context.Context, callSQL string, args ...any) (json.RawMessage, error) {
	q := "SELECT COALESCE(json_agg(t), '[]'::json) FROM (SELECT * FROM " + callSQL + ") t"
	var raw []byte
	if err := a.db.QueryRow(ctx, q, args...).Scan(&raw); err != nil {
		return nil, err
	}
	if raw == nil {
		return json.RawMessage("[]"), nil
	}
	return json.RawMessage(raw), nil
}

func (a *app) tableOneAsJSON(ctx context.Context, callSQL string, args ...any) (json.RawMessage, error) {
	q := "SELECT to_jsonb(t) FROM (SELECT * FROM " + callSQL + " LIMIT 1) t"
	var raw []byte
	if err := a.db.QueryRow(ctx, q, args...).Scan(&raw); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return json.RawMessage("null"), nil
		}
		return nil, err
	}
	if raw == nil {
		return json.RawMessage("null"), nil
	}
	return json.RawMessage(raw), nil
}

func buildFunctionCallSQL(name string, argc int) string {
	if argc <= 0 {
		return name + "()"
	}
	parts := make([]string, argc)
	for i := 0; i < argc; i++ {
		parts[i] = "$" + strconv.Itoa(i+1)
	}
	return fmt.Sprintf("%s(%s)", name, strings.Join(parts, ", "))
}

func decodeJSON(r *http.Request, dst any) error {
	if r.Body == nil {
		return errors.New("request body is required")
	}
	defer r.Body.Close()
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	if err := dec.Decode(dst); err != nil {
		if errors.Is(err, io.EOF) {
			return nil
		}
		return fmt.Errorf("invalid json: %w", err)
	}
	return nil
}

func extractSessionToken(r *http.Request) string {
	auth := strings.TrimSpace(r.Header.Get("Authorization"))
	if strings.HasPrefix(strings.ToLower(auth), "bearer ") {
		return strings.TrimSpace(auth[7:])
	}
	if v := strings.TrimSpace(r.Header.Get("X-Session-Token")); v != "" {
		return v
	}
	if c, err := r.Cookie("session_token"); err == nil && c.Value != "" {
		return strings.TrimSpace(c.Value)
	}
	return ""
}

func requireUser(w http.ResponseWriter, r *http.Request) (authUser, bool) {
	u, ok := getUser(r.Context())
	if !ok {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return authUser{}, false
	}
	return u, true
}

func getUser(ctx context.Context) (authUser, bool) {
	v := ctx.Value(userContextKey)
	if v == nil {
		return authUser{}, false
	}
	u, ok := v.(authUser)
	return u, ok
}

func writeJSON(w http.ResponseWriter, status int, payload any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(payload)
}

func writeError(w http.ResponseWriter, status int, msg string) {
	writeJSON(w, status, map[string]any{
		"error": msg,
		"ok":    false,
	})
}

func decodeRawAny(raw json.RawMessage) any {
	var out any
	if err := json.Unmarshal(raw, &out); err != nil {
		return nil
	}
	return out
}

func decodeRawSliceMap(raw json.RawMessage) []map[string]any {
	var out []map[string]any
	_ = json.Unmarshal(raw, &out)
	if out == nil {
		return []map[string]any{}
	}
	return out
}

func queryStringOrNil(r *http.Request, key string) any {
	v := strings.TrimSpace(r.URL.Query().Get(key))
	if v == "" {
		return nil
	}
	return v
}

func queryStringDefault(r *http.Request, key, fallback string) string {
	v := strings.TrimSpace(r.URL.Query().Get(key))
	if v == "" {
		return fallback
	}
	return v
}

func queryIntDefault(r *http.Request, key string, fallback int) int {
	v := strings.TrimSpace(r.URL.Query().Get(key))
	if v == "" {
		return fallback
	}
	n, err := strconv.Atoi(v)
	if err != nil {
		return fallback
	}
	return n
}

func queryIntOrNil(r *http.Request, key string) any {
	v := strings.TrimSpace(r.URL.Query().Get(key))
	if v == "" {
		return nil
	}
	n, err := strconv.Atoi(v)
	if err != nil {
		return nil
	}
	return n
}

func nilIfPtr(v *string) any {
	if v == nil {
		return nil
	}
	s := strings.TrimSpace(*v)
	if s == "" {
		return nil
	}
	return s
}

func isJSONBoolFalse(raw json.RawMessage) bool {
	var b bool
	if err := json.Unmarshal(raw, &b); err != nil {
		return false
	}
	return !b
}

func normalizeArg(v any) any {
	switch t := v.(type) {
	case float64:
		if float64(int64(t)) == t {
			return int64(t)
		}
		return t
	case []any:
		for i := range t {
			t[i] = normalizeArg(t[i])
		}
		return t
	case map[string]any:
		for k := range t {
			t[k] = normalizeArg(t[k])
		}
		return t
	default:
		return v
	}
}

func envOrDefault(key, fallback string) string {
	if v := strings.TrimSpace(os.Getenv(key)); v != "" {
		return v
	}
	return fallback
}

func envBoolDefault(key string, fallback bool) bool {
	v := strings.TrimSpace(strings.ToLower(os.Getenv(key)))
	if v == "" {
		return fallback
	}
	switch v {
	case "1", "true", "yes", "on":
		return true
	case "0", "false", "no", "off":
		return false
	default:
		return fallback
	}
}

func clientIP(r *http.Request) string {
	if v := strings.TrimSpace(r.Header.Get("X-Forwarded-For")); v != "" {
		parts := strings.Split(v, ",")
		if len(parts) > 0 {
			return strings.TrimSpace(parts[0])
		}
	}
	if v := strings.TrimSpace(r.Header.Get("X-Real-IP")); v != "" {
		return v
	}
	host, _, err := net.SplitHostPort(strings.TrimSpace(r.RemoteAddr))
	if err == nil {
		return host
	}
	return "127.0.0.1"
}
