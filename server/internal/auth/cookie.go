package auth

import (
	"crypto/rand"
	"encoding/hex"
	"net/http"
	"os"
	"strings"
	"time"
)

const (
	AuthCookieName = "multica_auth"
	CSRFCookieName = "multica_csrf"
	authCookieMaxAge = 30 * 24 * 60 * 60 // 30 days in seconds
)

func cookieDomain() string {
	return strings.TrimSpace(os.Getenv("COOKIE_DOMAIN"))
}

func isSecureCookie() bool {
	env := os.Getenv("APP_ENV")
	return env == "production" || env == "staging"
}

func generateCSRFToken() (string, error) {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return hex.EncodeToString(b), nil
}

// SetAuthCookies sets the HttpOnly auth cookie and the readable CSRF cookie on the response.
func SetAuthCookies(w http.ResponseWriter, token string) error {
	secure := isSecureCookie()
	domain := cookieDomain()

	http.SetCookie(w, &http.Cookie{
		Name:     AuthCookieName,
		Value:    token,
		Path:     "/",
		Domain:   domain,
		MaxAge:   authCookieMaxAge,
		Expires:  time.Now().Add(30 * 24 * time.Hour),
		HttpOnly: true,
		Secure:   secure,
		SameSite: http.SameSiteLaxMode,
	})

	csrfToken, err := generateCSRFToken()
	if err != nil {
		return err
	}

	http.SetCookie(w, &http.Cookie{
		Name:     CSRFCookieName,
		Value:    csrfToken,
		Path:     "/",
		Domain:   domain,
		MaxAge:   authCookieMaxAge,
		Expires:  time.Now().Add(30 * 24 * time.Hour),
		HttpOnly: false,
		Secure:   secure,
		SameSite: http.SameSiteLaxMode,
	})

	return nil
}

// ClearAuthCookies removes the auth and CSRF cookies.
func ClearAuthCookies(w http.ResponseWriter) {
	domain := cookieDomain()
	secure := isSecureCookie()

	http.SetCookie(w, &http.Cookie{
		Name:     AuthCookieName,
		Value:    "",
		Path:     "/",
		Domain:   domain,
		MaxAge:   -1,
		Expires:  time.Unix(0, 0),
		HttpOnly: true,
		Secure:   secure,
		SameSite: http.SameSiteLaxMode,
	})

	http.SetCookie(w, &http.Cookie{
		Name:     CSRFCookieName,
		Value:    "",
		Path:     "/",
		Domain:   domain,
		MaxAge:   -1,
		Expires:  time.Unix(0, 0),
		HttpOnly: false,
		Secure:   secure,
		SameSite: http.SameSiteLaxMode,
	})
}

// ValidateCSRF checks that the X-CSRF-Token header matches the CSRF cookie.
// Returns true if validation passes (including for safe methods that don't need CSRF).
func ValidateCSRF(r *http.Request) bool {
	switch r.Method {
	case http.MethodGet, http.MethodHead, http.MethodOptions:
		return true
	}

	csrfCookie, err := r.Cookie(CSRFCookieName)
	if err != nil || csrfCookie.Value == "" {
		return false
	}

	csrfHeader := r.Header.Get("X-CSRF-Token")
	return csrfHeader != "" && csrfHeader == csrfCookie.Value
}
