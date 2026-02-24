package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"io"
	"log"
	"net/http"
	"os"
	"strconv"
	"strings"
	"time"

	"github.com/go-chi/chi/v5"
	"github.com/go-chi/chi/v5/middleware"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgconn"
	"github.com/jackc/pgx/v5/pgxpool"
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
	db  *pgxpool.Pool
	fns map[string]fnDef
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

	a := &app{db: pool, fns: buildFunctionRegistry()}

	r := chi.NewRouter()
	r.Use(middleware.RequestID)
	r.Use(middleware.RealIP)
	r.Use(middleware.Recoverer)
	r.Use(middleware.Logger)
	r.Use(a.optionalAuth)

	r.Get("/healthz", a.handleHealth)
	r.Get("/api/me", a.handleMe)
	r.Post("/api/v1/rpc/{function}", a.handleRPC)

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
		SELECT user_id::text, email::text, username::text, display_name, avatar_url, is_active
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
