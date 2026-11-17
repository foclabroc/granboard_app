// Relais TURN de Foclaboard (vidéo du jeu en ligne quand les 2 téléphones
// ne peuvent pas se joindre directement, par exemple en 4G).
//
// Un seul exécutable, sans installation : il lit turn.json posé à côté de
// lui, écoute en UDP et TCP (3478 par défaut) et relaie sur une plage de
// ports UDP. Les identifiants sont donnés par le serveur Foclaboard
// (gb__on_ice) : utilisateur « expiration:joueur », mot de passe =
// base64(HMAC-SHA1(secret, utilisateur)) ; même secret des deux côtés.
//
// L'adresse publique est relue toutes les 5 minutes (nom duckdns, sinon
// service d'IP publique) ; si elle change, le relais redémarre tout seul.
//
// Compilation pour Windows (sans fenêtre) :
//
//	GOOS=windows GOARCH=amd64 go build -ldflags "-s -w -H windowsgui" -o foclaboard-turn.exe
package main

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/pion/logging"
	"github.com/pion/turn/v4"
)

type config struct {
	// Nom public du serveur (duckdns) : sert à trouver l'adresse publique.
	Host string `json:"host"`
	// Adresse publique forcée (sinon trouvée avec Host ou un service web).
	PublicIP string `json:"public_ip"`
	Port     int    `json:"port"`
	RelayMin int    `json:"relay_min"`
	RelayMax int    `json:"relay_max"`
	Realm    string `json:"realm"`
	Secret   string `json:"secret"`
	// Allocations ouvertes en même temps au plus (toutes confondues).
	MaxAllocations int `json:"max_allocations"`
}

func defaults() config {
	return config{
		Host:           "foclabroc.duckdns.org",
		Port:           3478,
		RelayMin:       49152,
		RelayMax:       49251,
		Realm:          "foclaboard",
		MaxAllocations: 60,
	}
}

var logMu sync.Mutex

// Journal turn.log à côté de l'exe (repart de zéro au-delà de 2 Mo).
type rotatingLog struct{ path string }

func (r rotatingLog) Write(p []byte) (int, error) {
	logMu.Lock()
	defer logMu.Unlock()
	if st, err := os.Stat(r.path); err == nil && st.Size() > 2<<20 {
		_ = os.Rename(r.path, r.path+".old")
	}
	f, err := os.OpenFile(r.path, os.O_CREATE|os.O_APPEND|os.O_WRONLY, 0o644)
	if err != nil {
		return len(p), nil
	}
	defer f.Close()
	return f.Write(p)
}

func main() {
	exe, _ := os.Executable()
	dir := filepath.Dir(exe)
	cfgPath := flag.String("config", filepath.Join(dir, "turn.json"), "fichier de réglages")
	check := flag.Bool("test", false, "teste le relais (allocation avec le secret) puis s'arrête")
	flag.Parse()

	// L'exe Windows n'a pas de console : le test écrit aussi dans turn-test.txt
	var out io.Writer = os.Stdout
	if *check {
		if f, err := os.Create(filepath.Join(dir, "turn-test.txt")); err == nil {
			defer f.Close()
			out = io.MultiWriter(os.Stdout, f)
		}
		log.SetOutput(out)
	} else {
		log.SetOutput(io.MultiWriter(rotatingLog{filepath.Join(dir, "turn.log")}, os.Stderr))
	}
	log.SetFlags(log.Ldate | log.Ltime)

	cfg, err := loadConfig(*cfgPath)
	if err != nil {
		log.Fatalf("réglages : %v", err)
	}
	if *check {
		if err := selfTest(cfg, out); err != nil {
			fmt.Fprintln(out, "ECHEC :", err)
			return
		}
		fmt.Fprintln(out, "OK : le relais repond et le secret est bon.")
		return
	}
	run(cfg)
}

func loadConfig(path string) (config, error) {
	cfg := defaults()
	b, err := os.ReadFile(path)
	if errors.Is(err, os.ErrNotExist) {
		// Premier lancement : réglages par défaut avec un secret tiré au hasard
		buf := make([]byte, 24)
		if _, err := rand.Read(buf); err != nil {
			return cfg, err
		}
		cfg.Secret = base64.RawURLEncoding.EncodeToString(buf)
		out, _ := json.MarshalIndent(cfg, "", "  ")
		if err := os.WriteFile(path, out, 0o600); err != nil {
			return cfg, err
		}
		log.Printf("turn.json créé (%s) : mets le même secret dans gb_config", path)
		return cfg, nil
	}
	if err != nil {
		return cfg, err
	}
	if err := json.Unmarshal(b, &cfg); err != nil {
		return cfg, fmt.Errorf("%s illisible : %w", path, err)
	}
	if cfg.Secret == "" {
		return cfg, errors.New("secret vide dans turn.json")
	}
	if cfg.RelayMin <= 0 || cfg.RelayMax < cfg.RelayMin || cfg.RelayMax > 65535 {
		return cfg, errors.New("plage relay_min / relay_max invalide")
	}
	return cfg, nil
}

// Adresse IPv4 publique : forcée, sinon le nom duckdns, sinon un service web.
func publicIP(cfg config) (net.IP, error) {
	if cfg.PublicIP != "" {
		if ip := net.ParseIP(cfg.PublicIP).To4(); ip != nil {
			return ip, nil
		}
		return nil, fmt.Errorf("public_ip invalide : %q", cfg.PublicIP)
	}
	if cfg.Host != "" {
		ctx, cancel := context.WithTimeout(context.Background(), 8*time.Second)
		addrs, err := net.DefaultResolver.LookupIP(ctx, "ip4", cfg.Host)
		cancel()
		if err == nil && len(addrs) > 0 {
			return addrs[0].To4(), nil
		}
	}
	for _, u := range []string{"https://api.ipify.org", "https://ifconfig.me/ip"} {
		c := http.Client{Timeout: 8 * time.Second}
		resp, err := c.Get(u)
		if err != nil {
			continue
		}
		b, _ := io.ReadAll(io.LimitReader(resp.Body, 64))
		resp.Body.Close()
		if ip := net.ParseIP(strings.TrimSpace(string(b))).To4(); ip != nil {
			return ip, nil
		}
	}
	return nil, errors.New("adresse publique introuvable")
}

type limiter struct {
	mu  sync.Mutex
	n   int
	max int
}

func run(cfg config) {
	log.Printf("Relais TURN Foclaboard : port %d (UDP+TCP), relais UDP %d-%d", cfg.Port, cfg.RelayMin, cfg.RelayMax)
	var ip net.IP
	for {
		var err error
		ip, err = publicIP(cfg)
		if err == nil {
			break
		}
		log.Printf("%v ; nouvel essai dans 30 s", err)
		time.Sleep(30 * time.Second)
	}
	for {
		srv, err := start(cfg, ip)
		if err != nil {
			log.Printf("démarrage impossible : %v ; nouvel essai dans 30 s", err)
			time.Sleep(30 * time.Second)
			continue
		}
		log.Printf("en marche, adresse publique %s", ip)
		// Surveille l'adresse publique (box qui change d'IP)
		for {
			time.Sleep(5 * time.Minute)
			now, err := publicIP(cfg)
			if err != nil || now.Equal(ip) {
				continue
			}
			log.Printf("adresse publique changée : %s → %s, redémarrage", ip, now)
			ip = now
			break
		}
		_ = srv.Close()
	}
}

func start(cfg config, ip net.IP) (*turn.Server, error) {
	addr := "0.0.0.0:" + strconv.Itoa(cfg.Port)
	udp, err := net.ListenPacket("udp4", addr)
	if err != nil {
		return nil, err
	}
	tcp, err := net.Listen("tcp4", addr)
	if err != nil {
		udp.Close()
		return nil, err
	}
	gen := func() turn.RelayAddressGenerator {
		return &turn.RelayAddressGeneratorPortRange{
			RelayAddress: ip,
			Address:      "0.0.0.0",
			MinPort:      uint16(cfg.RelayMin),
			MaxPort:      uint16(cfg.RelayMax),
		}
	}
	lf := logging.NewDefaultLoggerFactory()
	lf.DefaultLogLevel = logging.LogLevelWarn
	lf.Writer = log.Writer()
	auth := turn.LongTermTURNRESTAuthHandler(cfg.Secret, lf.NewLogger("auth"))
	lim := &limiter{max: cfg.MaxAllocations}
	// Sécurité : le relais ne joint que des adresses publiques (ou lui-même,
	// quand les deux téléphones passent par le relais). Jamais le réseau de
	// la maison (box, mini PC, Postgres…), ni 127.0.0.1.
	allow := func(_ net.Addr, peer net.IP) bool {
		if peer.Equal(ip) {
			return true
		}
		ok := !(peer.IsLoopback() || peer.IsPrivate() || peer.IsUnspecified() ||
			peer.IsLinkLocalUnicast() || peer.IsLinkLocalMulticast() ||
			peer.IsMulticast() || peer.IsInterfaceLocalMulticast())
		if v4 := peer.To4(); v4 != nil && v4[0] == 100 && v4[1]&0xc0 == 64 {
			ok = false // 100.64.0.0/10 (réseau de l'opérateur)
		}
		if !ok {
			log.Printf("refusé : relais vers l'adresse privée %s", peer)
		}
		return ok
	}
	return turn.NewServer(turn.ServerConfig{
		Realm:         cfg.Realm,
		LoggerFactory: lf,
		AuthHandler:   auth,
		QuotaHandler: func(username, realm string, src net.Addr) bool {
			lim.mu.Lock()
			defer lim.mu.Unlock()
			return lim.max <= 0 || lim.n < lim.max
		},
		EventHandler: turn.EventHandler{
			OnAllocationCreated: func(src, dst net.Addr, proto, user, realm string, relay net.Addr, port int) {
				lim.mu.Lock()
				lim.n++
				n := lim.n
				lim.mu.Unlock()
				log.Printf("relais ouvert : %s (%s) → %v [%d en cours]", user, src, relay, n)
			},
			OnAllocationDeleted: func(src, dst net.Addr, proto, user, realm string) {
				lim.mu.Lock()
				if lim.n > 0 {
					lim.n--
				}
				lim.mu.Unlock()
			},
		},
		PacketConnConfigs: []turn.PacketConnConfig{{PacketConn: udp, RelayAddressGenerator: gen(), PermissionHandler: allow}},
		ListenerConfigs:   []turn.ListenerConfig{{Listener: tcp, RelayAddressGenerator: gen(), PermissionHandler: allow}},
	})
}

// Allocation de test sur 127.0.0.1 avec un identifiant fabriqué comme celui
// du serveur Foclaboard.
func selfTest(cfg config, out io.Writer) error {
	user, pass, err := turn.GenerateLongTermTURNRESTCredentials(cfg.Secret, "test", time.Hour)
	if err != nil {
		return err
	}
	conn, err := net.ListenPacket("udp4", "0.0.0.0:0")
	if err != nil {
		return err
	}
	defer conn.Close()
	server := "127.0.0.1:" + strconv.Itoa(cfg.Port)
	c, err := turn.NewClient(&turn.ClientConfig{
		STUNServerAddr: server,
		TURNServerAddr: server,
		Conn:           conn,
		Username:       user,
		Password:       pass,
		Realm:          cfg.Realm,
		LoggerFactory:  logging.NewDefaultLoggerFactory(),
	})
	if err != nil {
		return err
	}
	defer c.Close()
	if err := c.Listen(); err != nil {
		return err
	}
	relay, err := c.Allocate()
	if err != nil {
		return fmt.Errorf("allocation refusée (relais lancé ? même secret ?) : %w", err)
	}
	defer relay.Close()
	fmt.Fprintln(out, "Adresse de relais donnee :", relay.LocalAddr())
	return nil
}
