# ERA - ANSI Data Extractor (Vapor Edition)

Une application web moderne pour extraire des messages de longueur variable à partir de données ANSI en utilisant l'algorithme **SignalingFlexible**.

✨ **Bienvenue dans ERA - ANSI Data Extractor!**

---

## 🎯 Caractéristiques

### ✅ Core Features
- **SignalingFlexible Algorithm** : Extraction optimisée de messages de longueur variable
- **8 délimiteurs ANSI standard** : SOH/ETX, STX/ETX, STX/ETB, SOH/EOT, FS/GS, RS/US, ESC/ESC, DLE/DLE
- **Délimiteurs personnalisés** : Support pour valeurs hex personnalisées (ex: 0x01, 0x03)
- **Upload de fichiers** : Drag-drop jusqu'à 100MB
- **Paste hex/base64** : Colle directement des données encodées
- **Export JSON** : Télécharge les résultats avec métadonnées
- **Historique** : Sauvegarde automatique (localStorage)
- **Pagination** : Affichage des résultats par pages
- **Statistiques** : Métriques de traitement en temps réel

### 🏗️ Architecture
- **Backend** : Vapor (Swift framework web haute performance)
- **Frontend** : HTML5 + CSS3 + JavaScript vanilla (aucune dépendance)
- **Deployment** : Docker + Fly.io (1 commande)
- **Type Safety** : Swift (100% type-safe)

---

## 📦 Structure du Projet

```
era-vapor/
├── Sources/
│   └── App/
│       ├── main.swift                  ← Point d'entrée
│       ├── Algorithms/
│       │   └── SignalingFlexible.swift ← Algorithme principal
│       ├── Models/
│       │   └── Delimiters.swift        ← Configuration délimiteurs
│       └── Routes/
│           └── ExtractionRoutes.swift  ← API endpoints
├── Public/
│   └── index.html                      ← Interface web complète
├── Package.swift                       ← Dépendances Swift
├── Dockerfile                          ← Build multi-stage
├── fly.toml                            ← Config Fly.io
└── README.md                           ← Documentation
```

---

## 🚀 Démarrage Rapide

### Prérequis

- **Swift 5.9+** (macOS: inclus dans Xcode)
- **Fly.io CLI** (pour déploiement)

```bash
# Installation Fly.io
curl -L https://fly.io/install.sh | sh
```

### 1. Setup Local

```bash
cd era-vapor

# Build
swift build

# Exécuter localement
swift run App serve --hostname localhost --port 8080
```

Le serveur démarre à : **http://localhost:8080**

### 2. Tester Localement

Ouvre http://localhost:8080 dans ton navigateur et teste:
- Upload un fichier
- Paste des données hex
- Change les délimiteurs
- Exporte les résultats

### 3. Déployer sur Fly.io

```bash
# Login (une seule fois)
flyctl auth login

# Déployer
flyctl launch --dockerfile Dockerfile --name era-extractor

# Ou redéployer après modifications
flyctl deploy
```

**Boum! 🚀 Ton app est live!**

Accède à: `https://era-extractor.fly.dev`

---

## 📡 API Endpoints

### GET `/api/health`
Health check endpoint.

**Response:**
```
OK
```

---

### GET `/api/delimiters`
Liste tous les délimiteurs disponibles.

**Response:**
```json
{
  "delimiters": [
    {
      "id": "0",
      "name": "SOH/ETX",
      "startChar": 1,
      "endChar": 3,
      "description": "Start of Heading / End of Text"
    }
  ]
}
```

---

### POST `/api/extract`
Extrait des messages à partir de données hex ou base64.

**Request:**
```json
{
  "data": "01HELLO03",
  "encoding": "hex",
  "delimiter": "SOH/ETX"
}
```

**Query Parameters (optionnel):**
- `customStart`: Hex personnalisé (ex: "0x01")
- `customEnd`: Hex personnalisé (ex: "0x03")

**Response:**
```json
{
  "id": "uuid-string",
  "sequences": ["HELLO", "WORLD"],
  "statistics": {
    "count": 2,
    "duration": 1.23,
    "bitsProcessed": 80,
    "avgMessageLength": 5.0,
    "minMessageLength": 5,
    "maxMessageLength": 5
  },
  "timestamp": "2024-10-23T10:30:00Z",
  "delimiter": {
    "id": "0",
    "name": "SOH/ETX",
    "startChar": 1,
    "endChar": 3
  }
}
```

---

### POST `/api/extract-file`
Extrait des messages à partir d'un fichier uploadé.

**Request (Multipart):**
```
POST /api/extract-file?delimiter=SOH/ETX
Content-Type: multipart/form-data

file: [binary file data]
```

**Query Parameters:**
- `delimiter`: Nom du délimiteur (défaut: "SOH/ETX")
- `customStart`: Hex personnalisé (optionnel)
- `customEnd`: Hex personnalisé (optionnel)

**Response:**
Même format que `/api/extract`

---

## 🔧 Configuration

### Variables d'Environnement

```bash
# Port (défaut: 8080 sur Fly.io)
PORT=8080

# Niveau de log (debug, info, warning, error)
LOG_LEVEL=info

# Environnement
ENVIRONMENT=production
```

### Limits
- **Max file size** : 100MB (configurable dans `ExtractionRoutes.swift`)
- **Max delimiters** : 8 presets + unlimited custom
- **History** : 20 derniers extractions (localStorage)

---

## 📊 Performance

- **Build time** : ~30-60 secondes (premier build)
- **Startup time** : < 1 seconde
- **Container size** : ~200MB (multi-stage optimisé)
- **Memory usage** : ~50MB au repos
- **Max file processing** : 100MB en streaming

---

## 🛠️ Développement

### Build Debug

```bash
swift build
swift run App serve --hostname localhost --port 8080
```

### Build Release

```bash
swift build -c release
```

### Tester avec cURL

```bash
# Health check
curl http://localhost:8080/api/health

# Get delimiters
curl http://localhost:8080/api/delimiters

# Extract from hex
curl -X POST http://localhost:8080/api/extract \
  -H "Content-Type: application/json" \
  -d '{
    "data": "01HELLO0348454c4c4f03",
    "encoding": "hex",
    "delimiter": "SOH/ETX"
  }'
```

---

## 🚀 Personnalisation

### Changer le nom de l'app

```bash
# Dans fly.toml:
app = "era-extractor"

# Changer à:
app = "my-awesome-extractor"

# Redéployer:
flyctl deploy
```

### Ajouter une nouvelle délimiteur

Édite `Sources/App/Models/Delimiters.swift`:

```swift
DelimiterPair(
    id: "8",
    name: "CUSTOM",
    startChar: 0xAB,
    endChar: 0xCD,
    description: "Ma délimiteur personnalisée"
)
```

### Changer la région Fly.io

```bash
# Dans fly.toml:
primary_region = "cdg"  # Paris
primary_region = "sjc"  # San Jose
primary_region = "lhr"  # London
primary_region = "nrt"  # Tokyo
```

---

## 📈 Prochaines Améliorations (optionnel)

1. **Base de données** : PostgreSQL pour l'historique persistant
2. **Authentication** : JWT pour utilisateurs
3. **Analytics** : Suivi des extractions
4. **Webhooks** : Notifications
5. **Batch Processing** : Queue pour très gros fichiers

---

## ❓ Troubleshooting

### Port already in use
```bash
lsof -i :8080 | grep LISTEN | awk '{print $2}' | xargs kill -9
```

### Build fails
```bash
# Nettoyer et reconstruire
rm -rf .build
swift build
```

### Docker build issues
```bash
# Réessayer avec plus de verbosité
docker build --no-cache -t era:test .
```

---

## 🎉 Vous Êtes Prêt!

```bash
# Development
swift build && swift run App serve --hostname localhost --port 8080

# Production (Docker)
docker build -t era:latest .
docker run -p 8080:8080 era:latest

# Deployment (Fly.io)
flyctl deploy
```

Ouvrez http://localhost:8080 et testez! 🚀

---

**Made with ❤️ for ANSI data extraction.**

Questions ? Consultez les routes API ci-dessus ou explorez le code source!
