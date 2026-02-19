package main

import (
	"database/sql"
	"encoding/json"
	"encoding/xml"
	"fmt"
	"log"
	"net/http"
	"os"
	"strings"

	_ "github.com/mattn/go-sqlite3"
)

type AuthenticationMethod struct {
	Method             string `json:"method" xml:"method"`
	MethodFriendlyName string `json:"methodFriendlyName" xml:"methodFriendlyName"`
	Message            string `json:"message" xml:"message"`
	PasswordHint       string `json:"passwordHint" xml:"passwordHint"`
}

type ProfileConfig struct {
	Server                              string                 `json:"server" xml:"server"`
	Domain                              string                 `json:"domain" xml:"domain"`
	Service                             string                 `json:"service" xml:"service"`
	Certificate                         string                 `json:"certificate" xml:"certificate"`
	Sudo                                bool                   `json:"sudo" xml:"sudo"`
	KerberosRealm                       string                 `json:"kerberosrealm" xml:"kerberosrealm"`
	AutomaticKerberosSync               bool                   `json:"automatickerberossync" xml:"automatickerberossync"`
	ValidPasswordIsSufficient           bool                   `json:"validPasswordIsSufficient" xml:"validPasswordIsSufficient"`
	ValidPasswordIsSufficientForOffline bool                   `json:"validPasswordIsSufficientForOffline" xml:"validPasswordIsSufficientForOffline"`
	MFA                                 bool                   `json:"mfa" xml:"mfa"`
	ForceLockAfterOfflineLogin          bool                   `json:"forceLockAfterOfflineLogin" xml:"forceLockAfterOfflineLogin"`
	PasswordFree                        bool                   `json:"passwordfree" xml:"passwordfree"`
	ThirdParty                          string                 `json:"thirdparty" xml:"thirdparty"`
	SSOURL                              string                 `json:"ssourl" xml:"ssourl"`
	SSOBrowser                          string                 `json:"ssobrowser" xml:"ssobrowser"`
	AutoPasswordSync                    bool                   `json:"autoPasswordSync" xml:"autoPasswordSync"`
	ForcePasswordRotation               bool                   `json:"forcePasswordRotation" xml:"forcePasswordRotation"`
	PasswordRotationPeriod              int                    `json:"passwordRotationPeriod" xml:"passwordRotationPeriod"`
	FileVaultLogin                      string                 `json:"filevaultlogin" xml:"filevaultlogin"`
	CustomUnlockScreen                  bool                   `json:"customUnlockScreen" xml:"customUnlockScreen"`
	AuthenticationMethods               []AuthenticationMethod `json:"authenticationMethods" xml:"authenticationMethods>struct"`
	SharedAccounts                      bool                   `json:"sharedaccounts" xml:"sharedaccounts"`
	ShowSharedAccountLink               bool                   `json:"showSharedAccountLink" xml:"showSharedAccountLink"`
	DefaultToRegularAccount             bool                   `json:"defaultToRegularAccount" xml:"defaultToRegularAccount"`
	NameForUseSharedAccountLink         string                 `json:"nameForUseSharedAccountLink" xml:"nameForUseSharedAccountLink"`
	NameForRemoveSharedAccountLink      string                 `json:"nameForRemoveSharedAccountLink" xml:"nameForRemoveSharedAccountLink"`
	Logging                             string                 `json:"logging" xml:"logging"`
	MaxAuditFileSize                    int                    `json:"maxAuditFileSize" xml:"maxAuditFileSize"`
	MaxLogFileSize                      int                    `json:"maxLogFileSize" xml:"maxLogFileSize"`
}

type Profile struct {
	ID          int           `json:"id"`
	Name        string        `json:"name"`
	Description string        `json:"description"`
	Config      ProfileConfig `json:"config"`
}

type OctopusXML struct {
	XMLName xml.Name `xml:"octopus"`
	Config  ProfileConfig
}

var db *sql.DB

// Custom handler to debug routing
func debugHandler(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		log.Printf("Request: %s %s", r.Method, r.URL.Path)
		next.ServeHTTP(w, r)
	})
}

func main() {
	var err error
	db, err = sql.Open("sqlite3", "./db.sqlite")
	if err != nil {
		log.Fatal(err)
	}
	defer db.Close()

	// Create table if not exists
	_, err = db.Exec(`CREATE TABLE IF NOT EXISTS profiles (
		id INTEGER PRIMARY KEY AUTOINCREMENT,
		name TEXT UNIQUE,
		description TEXT,
		config_json TEXT
	)`)
	if err != nil {
		log.Fatal(err)
	}

	// Create a custom mux to handle API routes first
	mux := http.NewServeMux()

	// API routes - these must be registered BEFORE the catch-all handler
	mux.HandleFunc("/api/profiles", profilesHandler)
	mux.HandleFunc("/api/profiles/", profileHandler)
	mux.HandleFunc("/api/default-profiles", defaultProfilesHandler)
	mux.HandleFunc("/api/generate-xml/", generateXMLHandler)

	// Serve static files for everything else
	fileServer := http.FileServer(http.Dir("../frontend/build"))
	mux.HandleFunc("/", func(w http.ResponseWriter, r *http.Request) {
		// Only serve static files for non-API routes
		if !strings.HasPrefix(r.URL.Path, "/api/") {
			fileServer.ServeHTTP(w, r)
		} else {
			http.NotFound(w, r)
		}
	})

	port := os.Getenv("PORT")
	if port == "" {
		port = "5001"
	}
	log.Printf("Server running on :%s", port)
	http.ListenAndServe(":"+port, debugHandler(mux))
}

// Generate XML for a profile
func generateXMLHandler(w http.ResponseWriter, r *http.Request) {
	log.Printf("generateXMLHandler called")
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", 405)
		return
	}

	id := strings.TrimPrefix(r.URL.Path, "/api/generate-xml/")

	// Get profile from database
	row := db.QueryRow("SELECT id, name, description, config_json FROM profiles WHERE id = ?", id)
	var p Profile
	var configJSON string
	if err := row.Scan(&p.ID, &p.Name, &p.Description, &configJSON); err != nil {
		http.Error(w, "Profile not found", 404)
		return
	}
	if err := json.Unmarshal([]byte(configJSON), &p.Config); err != nil {
		http.Error(w, err.Error(), 500)
		return
	}

	// Generate XML
	octopusXML := OctopusXML{
		Config: p.Config,
	}

	xmlData, err := xml.MarshalIndent(octopusXML, "", "    ")
	if err != nil {
		http.Error(w, err.Error(), 500)
		return
	}

	// Add XML declaration
	xmlOutput := fmt.Sprintf("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n%s", string(xmlData))

	w.Header().Set("Content-Type", "application/xml")
	w.Header().Set("Content-Disposition", fmt.Sprintf("attachment; filename=\"%s.xml\"", p.Name))
	w.Write([]byte(xmlOutput))
}

// Get default profiles
func defaultProfilesHandler(w http.ResponseWriter, r *http.Request) {
	log.Printf("defaultProfilesHandler called")
	if r.Method != http.MethodGet {
		http.Error(w, "Method not allowed", 405)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type")

	defaultProfiles := []Profile{
		{
			Name:        "Passwordless",
			Description: "Full passwordless authentication with Octopus and FIDO2",
			Config: ProfileConfig{
				Server:                              "https://example.com",
				Domain:                              "acmecorp",
				Service:                             "ZaOC34qAU4S...2l33mDKYnsgKZQ==",
				Certificate:                         "-----BEGIN CERTIFICATE-----\n...\n-----END CERTIFICATE-----",
				Sudo:                                false,
				KerberosRealm:                       "",
				AutomaticKerberosSync:               true,
				ValidPasswordIsSufficient:           false,
				ValidPasswordIsSufficientForOffline: false,
				MFA:                                 false,
				ForceLockAfterOfflineLogin:          false,
				PasswordFree:                        true,
				ThirdParty:                          "false",
				SSOURL:                              "",
				SSOBrowser:                          "system",
				AutoPasswordSync:                    true,
				ForcePasswordRotation:               false,
				PasswordRotationPeriod:              30,
				FileVaultLogin:                      "client",
				CustomUnlockScreen:                  false,
				AuthenticationMethods: []AuthenticationMethod{
					{Method: "octopus", MethodFriendlyName: "", Message: "", PasswordHint: ""},
					{Method: "fido2", MethodFriendlyName: "", Message: "", PasswordHint: ""},
				},
				SharedAccounts:                 false,
				ShowSharedAccountLink:          false,
				DefaultToRegularAccount:        true,
				NameForUseSharedAccountLink:    "",
				NameForRemoveSharedAccountLink: "",
				Logging:                        "info",
				MaxAuditFileSize:               10000,
				MaxLogFileSize:                 10000,
			},
		},
		{
			Name:        "Password-free",
			Description: "Password-free authentication with Octopus only",
			Config: ProfileConfig{
				Server:                              "https://example.com",
				Domain:                              "acmecorp",
				Service:                             "ZaOC34qAU4S...2l33mDKYnsgKZQ==",
				Certificate:                         "-----BEGIN CERTIFICATE-----\n...\n-----END CERTIFICATE-----",
				Sudo:                                false,
				KerberosRealm:                       "",
				AutomaticKerberosSync:               true,
				ValidPasswordIsSufficient:           false,
				ValidPasswordIsSufficientForOffline: false,
				MFA:                                 false,
				ForceLockAfterOfflineLogin:          false,
				PasswordFree:                        true,
				ThirdParty:                          "false",
				SSOURL:                              "",
				SSOBrowser:                          "system",
				AutoPasswordSync:                    true,
				ForcePasswordRotation:               false,
				PasswordRotationPeriod:              30,
				FileVaultLogin:                      "client",
				CustomUnlockScreen:                  false,
				AuthenticationMethods: []AuthenticationMethod{
					{Method: "octopus", MethodFriendlyName: "", Message: "", PasswordHint: ""},
				},
				SharedAccounts:                 false,
				ShowSharedAccountLink:          false,
				DefaultToRegularAccount:        true,
				NameForUseSharedAccountLink:    "",
				NameForRemoveSharedAccountLink: "",
				Logging:                        "info",
				MaxAuditFileSize:               10000,
				MaxLogFileSize:                 10000,
			},
		},
		{
			Name:        "MFA",
			Description: "Multi-factor authentication with password and additional factors",
			Config: ProfileConfig{
				Server:                              "https://example.com",
				Domain:                              "acmecorp",
				Service:                             "ZaOC34qAU4S...2l33mDKYnsgKZQ==",
				Certificate:                         "-----BEGIN CERTIFICATE-----\n...\n-----END CERTIFICATE-----",
				Sudo:                                false,
				KerberosRealm:                       "",
				AutomaticKerberosSync:               true,
				ValidPasswordIsSufficient:           false,
				ValidPasswordIsSufficientForOffline: false,
				MFA:                                 true,
				ForceLockAfterOfflineLogin:          false,
				PasswordFree:                        false,
				ThirdParty:                          "false",
				SSOURL:                              "",
				SSOBrowser:                          "system",
				AutoPasswordSync:                    true,
				ForcePasswordRotation:               false,
				PasswordRotationPeriod:              30,
				FileVaultLogin:                      "client",
				CustomUnlockScreen:                  false,
				AuthenticationMethods: []AuthenticationMethod{
					{Method: "octopus", MethodFriendlyName: "", Message: "", PasswordHint: ""},
					{Method: "fido2", MethodFriendlyName: "", Message: "", PasswordHint: ""},
				},
				SharedAccounts:                 false,
				ShowSharedAccountLink:          false,
				DefaultToRegularAccount:        true,
				NameForUseSharedAccountLink:    "",
				NameForRemoveSharedAccountLink: "",
				Logging:                        "info",
				MaxAuditFileSize:               10000,
				MaxLogFileSize:                 10000,
			},
		},
	}

	json.NewEncoder(w).Encode(defaultProfiles)
}

// List and create profiles
func profilesHandler(w http.ResponseWriter, r *http.Request) {
	log.Printf("profilesHandler called")
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type")

	// Handle preflight requests
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}

	switch r.Method {
	case http.MethodGet:
		rows, err := db.Query("SELECT id, name, description, config_json FROM profiles")
		if err != nil {
			http.Error(w, err.Error(), 500)
			return
		}
		defer rows.Close()
		var profiles []Profile
		for rows.Next() {
			var p Profile
			var configJSON string
			if err := rows.Scan(&p.ID, &p.Name, &p.Description, &configJSON); err != nil {
				http.Error(w, err.Error(), 500)
				return
			}
			if err := json.Unmarshal([]byte(configJSON), &p.Config); err != nil {
				http.Error(w, err.Error(), 500)
				return
			}
			profiles = append(profiles, p)
		}
		json.NewEncoder(w).Encode(profiles)
	case http.MethodPost:
		var p Profile
		if err := json.NewDecoder(r.Body).Decode(&p); err != nil {
			http.Error(w, err.Error(), 400)
			return
		}

		configJSON, err := json.Marshal(p.Config)
		if err != nil {
			http.Error(w, err.Error(), 500)
			return
		}

		res, err := db.Exec("INSERT INTO profiles (name, description, config_json) VALUES (?, ?, ?)", p.Name, p.Description, string(configJSON))
		if err != nil {
			http.Error(w, err.Error(), 500)
			return
		}
		id, _ := res.LastInsertId()
		p.ID = int(id)
		json.NewEncoder(w).Encode(p)
	default:
		http.Error(w, "Method not allowed", 405)
	}
}

// Get, update, delete a profile
func profileHandler(w http.ResponseWriter, r *http.Request) {
	log.Printf("profileHandler called")
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PUT, DELETE, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type")

	// Handle preflight requests
	if r.Method == http.MethodOptions {
		w.WriteHeader(http.StatusOK)
		return
	}

	id := strings.TrimPrefix(r.URL.Path, "/api/profiles/")
	switch r.Method {
	case http.MethodGet:
		row := db.QueryRow("SELECT id, name, description, config_json FROM profiles WHERE id = ?", id)
		var p Profile
		var configJSON string
		if err := row.Scan(&p.ID, &p.Name, &p.Description, &configJSON); err != nil {
			http.Error(w, err.Error(), 404)
			return
		}
		if err := json.Unmarshal([]byte(configJSON), &p.Config); err != nil {
			http.Error(w, err.Error(), 500)
			return
		}
		json.NewEncoder(w).Encode(p)
	case http.MethodPut:
		var p Profile
		if err := json.NewDecoder(r.Body).Decode(&p); err != nil {
			http.Error(w, err.Error(), 400)
			return
		}

		configJSON, err := json.Marshal(p.Config)
		if err != nil {
			http.Error(w, err.Error(), 500)
			return
		}

		_, err = db.Exec("UPDATE profiles SET name=?, description=?, config_json=? WHERE id=?", p.Name, p.Description, string(configJSON), id)
		if err != nil {
			http.Error(w, err.Error(), 500)
			return
		}
		json.NewEncoder(w).Encode(p)
	case http.MethodDelete:
		_, err := db.Exec("DELETE FROM profiles WHERE id=?", id)
		if err != nil {
			http.Error(w, err.Error(), 500)
			return
		}
		w.WriteHeader(204)
	default:
		http.Error(w, "Method not allowed", 405)
	}
}
