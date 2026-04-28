# Constanza Músicas — Histórico de Versões

> Padrão: **MAJOR.MINOR.PATCH**
> - **MAJOR** — Mudanças que quebram compatibilidade / refatoração arquitetural
> - **MINOR** — Novas funcionalidades sem quebrar o que já existe
> - **PATCH** — Correções de bugs, ajustes de UI, melhorias de performance

---

## [1.3.0] — 2026-04-28
### Configurações enxutas
- **Removido** de Configurações: Densidade da Lista, Capa de Álbum na lista, Ordenação Padrão, Filtrar músicas curtas, Spotify API e Cache de análises.
- **Movido** para Library/Músicas: filtro de duração mínima — agora num painel expansível com slider 0–120s (substitui o toggle binário antigo).
- **Removido** o atalho "Pasta de Músicas" da página Músicas (fica só em Configurações).

### Onda 1 — Diagnóstico & base
- `flutter analyze` em **0 issues**.
- `AndroidManifest`: removido `android:requestLegacyExternalStorage` (`MediaTagPlugin` já usa `MediaStore`/`ContentResolver`).
- `main.dart`: silenciamento de `debugPrint` em `kReleaseMode` cobre 84 chamadas em 22 arquivos com uma única linha.
- `library_provider`: `dev.log` migrado para `debugPrint` (entra no mesmo pipeline).
- Auditoria de `dispose()` em 12 arquivos com `AnimationController`/`StreamSubscription`/`Timer` — todos OK, sem leaks.

### Onda 2 — Play Store readiness
- **Signing release**: `signingConfig` condicional via `android/key.properties` (fora do git); fallback para chave de debug em sideload.
- **R8 + shrinkResources** ativos em release; ProGuard rules cobrem `audio_service`, `just_audio`/ExoPlayer, JAudioTagger e plugins nativos.
- `key.properties.example` com instruções de `keytool`; `.gitignore` com padrões `*.jks`, `*.keystore`, `key.properties`.
- **Build release validado**: 58.4 MB.

### Onda 2 — Refatoração de `now_playing_page.dart`
- **6.438 → 3.417 linhas** via `part of` (preserva privacidade `_Class`, zero churn em imports).
- `now_playing/styles/`: 10 arquivos (classic, circular, large, full_blur, vinyl, minimalist, aurora, elegant, wave, mosaic).
- `now_playing/lyrics/`: 7 arquivos (lyrics_page, mini_player, view_mode, landscape, quick_sync, edit_view, empty).

### Onda 2 — Major dependency bumps
- `just_audio` 0.9.43 → **0.10.5**
- `permission_handler` 11.3.1 → **12.0.1**
- `share_plus` 10.0.0 → **11.1.0** (v12+ exige AGP ≥8.12.1 + Kotlin 2.2.0; v11 mantém mesma API `SharePlus.instance`)
- `cupertino_icons` adicionado para resolver warning de fontes no build.

### Onda 3 — Polish & Hardening
- **`ignore_for_file: deprecated_member_use`** removido dos 4 arquivos restantes; 6 deprecations corrigidas (`Switch.activeColor` → `activeThumbColor`, `Color.value` → `toARGB32()`).
- **`MediaTagPlugin`**: validação de path traversal + whitelist de extensões de áudio antes de qualquer `writeTags`/`deleteSong` (defesa em profundidade na fronteira nativa).
- **Diagnóstico no app**: nova seção em Configurações → SOBRE expõe contagem de logs de erro persistidos, com ações "Compartilhar logs" e "Limpar".
- **Backup & Restauração**: `BackupService` exporta playlists, favoritos, exclusões, histórico, settings de tema/áudio/biblioteca como JSON via Share; importação por área de transferência. `android:allowBackup` + `backup_rules.xml` + `data_extraction_rules.xml` para Auto Backup nativo.
- **Battery optimization**: novo tile em REPRODUÇÃO pede isenção do Doze mode (`Permission.ignoreBatteryOptimizations`).
- **Splash nativo** com ícone do app centralizado (`launch_background.xml`), em vez de fundo preto puro.

---

## [1.2.1] — 2026-04-25
### Adicionado
- **6 widgets para o ecrã inicial do Android** (home screen widgets nativos):
  - **Médio** (`MusicWidgetProvider`) — artwork grande esquerda + título/artista + controlos completos (repeat/prev/play/next/star)
  - **Grande** (`WidgetLargeProvider`) — artwork quase full-width + título/artista + controlos completos
  - **Médio + Pesquisa** (`WidgetMediumSearchProvider`) — linha compacta com barra de pesquisa que abre a app
  - **Cápsula** (`WidgetCapsuleProvider`) — formato pílula com artwork, título, play/pause e next
  - **Recomendação** (`WidgetRecommendationProvider`) — artwork de fundo com overlay escuro e label "Daily Recommendation"
  - **Recomendado** (`WidgetRecommendedProvider`) — artwork + transporte + grelha 2×2 de ações (fila, playlist, timer, favorito)

### Arquitetura
- `WidgetConstants.kt` — chaves SharedPreferences e nomes de ações centralizados
- `BaseWidgetProvider.kt` — lógica partilhada (leitura de prefs, artwork arredondado, PendingIntents, abertura da app)
- 5 novos providers Kotlin (Large, MediumSearch, Capsule, Recommendation, Recommended)
- `MusicWidgetProvider.kt` refatorado para usar `BaseWidgetProvider`
- `MainActivity.kt` notifica todos os 6 providers em cada `updateWidget`
- `AndroidManifest.xml` regista os 6 receivers com respetivos `appwidget-provider` info XMLs
- Todos os 6 layouts XML em `res/layout/` com fundo vinho escuro (`#E0521212`) e bordas arredondadas

---

## [1.2.0] — 2026-04-25
### Adicionado
- **Saída com confirmação**: toque duplo no botão voltar exibe snackbar "Toque duas vezes para sair" antes de fechar o app (`PopScope` em `AppShell`).
- **Modo multi-seleção** na página de Músicas: long-press numa música entra no modo de seleção; barra de ações inferior com Tocar, Playlist, Partilhar e Próxima; botões "Selecionar tudo" / "Desmarcar tudo" no AppBar; sair com botão X ou botão voltar.
- **Gestão granular de Pastas de Música** (`/folders`): dois níveis de controlo:
  - **Nível 1 — Pastas**: lista todas as pastas descobertas no dispositivo com checkbox para incluir/excluir a pasta inteira do scan; mosaico 2×2 das capas, caminho completo, contador "N incluídas / total"; checkbox com estado parcial (traço) quando apenas algumas músicas estão incluídas.
  - **Nível 2 — Músicas da pasta**: ao entrar numa pasta, lista cada música com checkbox individual para inclusão/exclusão fina do scan; toggle para ativar/desativar a pasta inteira; "Selecionar tudo" / "Desmarcar tudo"; aviso visual quando a pasta está desativada; as alterações são aplicadas com o botão "Aplicar" que guarda e re-escaneia a biblioteca.
- **NowPlayingCard** (`lib/presentation/widgets/now_playing_card.dart`): card moderno de reprodução reutilizável com gradiente dinâmico da palette da artwork, barra de progresso inline, controles prev/play/next e animação de entrada; pode ser integrado em qualquer página.
- **Partilha com poster visual**: ao partilhar uma música (menu de opções ou multi-seleção), o app gera automaticamente um poster 600×600 px com capa da música, nome do artista, fundo com gradiente dinâmico das cores da artwork e branding Constanza; o ficheiro PNG é enviado diretamente ao sistema de partilha do Android via `share_plus`.

### Arquitetura
- `SettingsStorageService`: novo campo `constanza_excluded_songs` (lista de IDs persistida).
- `LibraryState`: novo campo `excludedSongIds: Set<String>` propagado no estado reativo.
- `LibraryNotifier`: novo método `setExcludedSongs(ids)`, getter `allScannedSongs`, e `_applyFolderFilter` actualizado para aplicar a blacklist de IDs.

### Dependência adicionada
- `share_plus: ^10.0.0` — partilha de ficheiros via intent nativo Android

---

## [1.1.3] — 2026-04-24
### Melhorado
- Reprodução simultânea com outros apps: o app agora continua tocando mesmo quando YouTube, WhatsApp ou qualquer outro aplicativo começa a reproduzir áudio (sem pausar automaticamente).
  - `AudioPlayer` criado com `handleInterruptions: false` e `handleAudioSessionActivation: false`
  - `AudioSession` configurada com `mixWithOthers` (iOS) e `androidWillPauseWhenDucked: false`

---

## [1.1.2] — (sessão anterior)
### Adicionado
- Sistema ArtworkPalette multi-cor (dominant, vibrant, muted, secondary, tertiary)
- 5 novos estilos NowPlaying: minimalist, aurora, elegant, wave, mosaic (total: 10)
- Custom 3-color picker para cores do NowPlaying
- AnimatedContainer no mini player
- Cores dinâmicas no EQ baseadas na paleta da capa

---

## [1.1.1] — (sessão anterior)
### Adicionado
- 5 estilos NowPlaying: classic, circular, large, fullBlur, vinyl
- Bokeh layer animado (CustomPainter)
- 3 novos enums: NavBarStyle, MiniPlayerStyle, MediaBarStyle
- artworkColorProvider e artworkPaletteProvider

---

## [1.1.0] — (sessão anterior)
### Adicionado
- Favoritos com persistência (SettingsStorageService)
- Busca com filter chips + navegação + histórico persistido de pesquisas recentes
- BackgroundWrapper em rotas pushed
- Play Next e Add to Playlist no SongTile
- Accent color bottom sheet

---

## [1.0.3] — (sessão anterior)
### Adicionado
- Sistema de artwork com LRU cache (200 entradas)
- ArtworkImage widget reutilizável (.song() / .album())
- Integração em 15+ locais da UI

---

## [1.0.2] — (sessão anterior)
### Adicionado
- Playback real com just_audio (MockData removido)
- Conexão LibraryProvider ↔ PlayerProvider
- URI handling: content:// usa setUrl(), file paths usam setFilePath()

---

## [1.0.1] — (sessão anterior)
### Adicionado
- UI completa com Material 3 e sistema de temas
- 3 estilos de player iniciais
- Estrutura Clean Architecture (domain/presentation/services/core)
- State management com Riverpod + StateNotifier

---

## [1.0.0] — Versão inicial
- Primeira estrutura do projeto Constanza Músicas
