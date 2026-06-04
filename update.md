# Constanza Músicas — Histórico de Versões

> Padrão: **MAJOR.MINOR.PATCH**
> - **MAJOR** — Mudanças que quebram compatibilidade / refatoração arquitetural
> - **MINOR** — Novas funcionalidades sem quebrar o que já existe
> - **PATCH** — Correções de bugs, ajustes de UI, melhorias de performance

---

## [1.4.0] — 2026-06-04
### Barras de progresso — 11 novos estilos de visualizador
- **`MediaBarStyle` expandido de 6 → 17 estilos.** Além dos cinco sliders simples (Minimal, Brilho, Gradiente, Espessa, Clássico) e da Onda sonora já existente, agora há **11 visualizadores interativos** inspirados em designs de áudio profissionais, cada um podendo ser escolhido em **Configurações → Barra de progresso**:
  - **Frequências** — barras finas centradas com envelope tipo espectro.
  - **Barras** — gráfico de barras ancorado na base.
  - **Degraus** — barras quantizadas em níveis, formando escada.
  - **Equalizador** — colunas LED segmentadas (blocos empilhados).
  - **Segmentos** — medidor em blocos chunky arredondados.
  - **Pontilhado** — matriz de pontos (halftone) com queda em losango.
  - **Pulso** — linha de ECG/batimento estilizada (P-QRS-T).
  - **Onda suave** — senoide modulada por envelope (efeito de batimento).
  - **Onda** — senoide única e encorpada.
  - **Espelhada** — forma de onda simétrica preenchida (top/bottom).
  - **Espectro** — forma de onda densa de gravação (~104 traços finos).
- **Todos são "seek bars" reais**: tocar ou arrastar busca a posição; a porção tocada usa gradiente (acento → secundária → terciária da paleta da capa), a não tocada fica esmaecida, com playhead luminoso. Cada música mantém um desenho **determinístico** (semente = id da faixa), com animação viva e subtil.
- **Reflete no Now Playing e no Modo Carro.** Nova widget partilhada `MediaSeekBar` (`lib/presentation/widgets/media_seek_bar.dart`) centraliza render + gestos + animação; o `_ProgressBar` do Now Playing e o `_ProgressSection` do Modo Carro passaram a delegá-la. **O Modo Carro agora respeita o estilo escolhido** (antes ignorava e usava sempre um slider simples), derivando os tons do gradiente a partir do acento sobre fundo escuro.
- **Refatoração**: removidos `_WaveformSeekBar`/`_WaveformPainter`/`_GradientSliderTrackShape` duplicados de `now_playing_page.dart`; a lógica de SliderTheme dos cinco estilos simples também migrou para a widget partilhada (zero divergência entre as duas telas).
- **i18n**: 11 novas chaves `mediaBar*` em PT e EN.

---

## [1.3.5] — 2026-06-04
### Letras — precisão da busca online
- **Falha de rede tratada como "sem letra"**: `LyricsFetchService.fetch()`/`search()` engoliam timeout/erro de rede e retornavam `null` — o mesmo retorno de "esta música não tem letra". O chamador então gravava **permanentemente** `markOnlineMiss()`, obrigando o utilizador a buscar 2-3× até cair numa janela com rede boa.
- **Fix:** nova `LyricsNetworkException`, lançada após esgotar **3 tentativas com backoff** (350ms→1400ms) em timeout/socket/429/5xx. `fetch`/`search` só retornam `null` em **miss definitivo** (servidor respondeu sem letra). Timeout por pedido 10s → 12s.
- **Chamadores** (`_searchOnline`, diálogo de busca manual `_run`, Modo Carro): em exceção de rede **não marcam "sem letra"** — mostram "sem conexão" e voltam a buscar na próxima abertura/reprodução.

### BPM & Tonalidade — fim do "fica só processando"
- **FFT nativa recalculava `cos/sin` no butterfly** a cada um de ~5000 frames/música (`AudioAnalysisPlugin.kt`) — o gargalo que fazia a análise demorar dezenas de segundos. Agora usa **twiddle factors + índices de bit-reversal pré-computados por tamanho** (`FftPlan`/`planFor`) e **janela Hann pré-computada** no BPM. ~3-5× mais rápida, mesmo resultado.
- **Análise sob demanda**: deixou de rodar a cada troca de faixa (decodificar 60s via `MediaCodec` em paralelo com o playback). Agora só corre quando o badge de análise do Now Playing fica visível. Removido o gatilho automático em `PlayerNotifier._loadAndPlay`.
- **Timeout de segurança** de 45s em `NativeAudioAnalysisService.analyze` — o spinner do badge nunca gira eternamente (mídia malformada/codec lento → estado de retry).

### Player — faixas paravam de tocar após tempo em background
- **Sintoma:** após tocar por minutos/horas e sair do app, ao voltar mais tarde o `play()` não produzia som — só forçar o fecho (ou limpar dados) resolvia.
- **Causa provável:** ao ficar muito tempo em background, o SO recupera o decoder do just_audio e o player fica num estado morto (`idle`), com `play()` virando no-op silencioso. A pressão sobre o pool de `MediaCodec` pela análise DSP automática a cada faixa (ver acima) agravava o quadro.
- **Fix:** `PlayerNotifier.recoverIfNeeded()`, chamado no `resumed` do `AppShell`: se houver faixa carregada mas o handler estiver `idle`, re-prepara a faixa na última posição (pausada) para que o `play()` volte a funcionar sem reiniciar o processo. Combinado com a análise agora sob demanda, remove o principal estressor de codecs.

---

## [1.3.4] — 2026-05-14
### Correções de áudio & ícone
- **Zombie state no repeat (Android)**: após `ProcessingState.completed`, o pipeline de áudio do just_audio é encerrado no Android. `seek(zero)+play` deixava o player em estado mudo (posição avançava, sem som). Corrigido: `_onPlaybackCompleted` chama `_loadAndPlay()` em `RepeatMode.one`, que reinicializa o source e chama `resetVolume()`.
- **Volume zerado após crossfade**: `resetVolume()` adicionado antes de `seek` nos dois paths de navegação rápida (prev/next já em progresso), garantindo que o volume não fica em 0 quando o crossfade foi interrompido a meio.
- **Ícone do launcher**: novo ícone atualizado em todos os tamanhos (mdpi → xxxhdpi + drawable foreground); fundo do launcher alterado de `#000000` para `#1A1A2E`.

---

## [1.3.3] — 2026-05-09
### Posters de Partilha — Redesign Premium
- **`_SongPoster`** reformulado: arte de capa edge-to-edge no topo (1080 px), degradê inferior escuro sobre ela, conteúdo posicionado absolutamente (`Positioned`) com `spaceBetween` entre (TopBar + TitleBlock) e (Waveform + Branding). Elimina o espaço em branco desperdiciado (~400 px) que existia antes com `Spacer()`.
- **`_LyricsPoster`** redesenhado para replicar o visual do ecrã de letras do app: fundo `_LyricsBackground` (arte a 22% opacidade + sobreposição preta uniforme + dois blobs de cor nos cantos). Elimina o blob/mancha no centro causado pelo `RadialGradient` antigo.
- **`_LyricsHeader`** novo: miniatura 112 px + barra de acento + título/subtítulo — substitui o cabeçalho vazio anterior.
- **`_LyricsLinesView`**: linhas de letra centradas com espaçamento fixo de 28 px (`MainAxisAlignment.center`) em vez de `spaceEvenly` que deixava espaço excessivo em baixo.
- Removidas classes obsoletas `_PosterBackground` e `_ArtCard`.

### Backup & Restauração — Correção completa
- **Chave errada** (`constanza_history` → `constanza_play_history`): o histórico de reprodução nunca era exportado nem importado. Corrigido em `_exportedKeys` do `BackupService`.
- **Sem reload de providers após importação**: depois do `importFromString()`, o app não atualizava o estado em memória — as preferências importadas só apareciam após reiniciar o app. Corrigido: `settings_page.dart` agora chama `themeProvider.reloadFromStorage()`, `audioSettingsProvider.reloadFromStorage()`, `playlistProvider.loadFromStorage()` e `libraryProvider.reloadFromBackup()` imediatamente após a importação.
- **`_playlistsRestored` bloqueava restauração de playlists após rescan**: a flag só era verdadeira uma vez; quando o backup disparava um novo rescan da biblioteca, as músicas das playlists nunca eram resolvidas. Corrigido usando deteção de transição `wasNotLoaded && nowLoaded` em vez de flag one-shot.
- **`reloadFromBackup()`** novo em `LibraryNotifier`: recarrega favoritos/pastas excluídas/selecionadas do storage e chama `rescan()` — restauração completa sem reiniciar o app.
- `ThemeNotifier.reloadFromStorage()` e `AudioSettingsNotifier.reloadFromStorage()` tornados públicos para serem chamados externamente.
- `_BackupSheet` convertido de `StatefulWidget` → `ConsumerStatefulWidget` para ter acesso ao `ref` e chamar os providers após a importação.

---

## [1.3.2] — 2026-05-06
### Backup & Restauração — Seletor nativo de arquivos
- **Removida** a importação por área de transferência e o campo de caminho manual.
- **Substituídos** por um único botão **Importar backup** que abre o seletor nativo do Android (Storage Access Framework) filtrando `.json`. O utilizador navega no armazenamento, escolhe o arquivo e a restauração ocorre.
- Implementação usa `file_picker: ^8.1.4` com `withData: true` (lê os bytes via SAF, sem depender de path absoluto — funciona com Drive, Downloads, etc.) e fallback para leitura por path quando os bytes não vêm preenchidos.
- Decodificação UTF-8 com `allowMalformed: true` e tratamento de erros com `SnackBar` específico para arquivo vazio/ilegível vs. formato inválido.

### Now Playing — Correção de bug de retomada da tela
- **Bug A:** ao desligar a tela do telemóvel, pular faixas via notificação/headset e religar a tela com a NowPlaying visível, a faixa atual reiniciava do zero.
- **Bug B:** com **shuffle** ativo, ao religar a tela, o carrossel "embaralhava" rapidamente as capas e mudava a música sozinho.
- **Causa raiz:** quando o engine do Flutter é retomado após o ecrã acordar, frames de settle pendentes do `PageView` disparam `onPageChanged` sem intervenção do utilizador. O guard `_syncing` antigo não era robusto o suficiente — em alguns timings, o evento atrasado caía no caminho de "swipe real" e chamava `playIndex(idx)`/`notifier.next()`/`previous()`, reiniciando a faixa (sem shuffle) ou saltando para uma aleatória (com shuffle).
- **Fix:** envolvido o `PageView` com um `Listener` que regista o timestamp do último `PointerDown`. O `_onPageChanged` só trata o evento como swipe real quando houve toque nos últimos **800 ms**; caso contrário, apenas atualiza `_currentPage` sem chamar nenhuma navegação. Soluciona ambos os sintomas de forma definitiva.

---

## [1.3.1] — 2026-05-06
### Backup & Restauração — Importação por caminho
- **Novo** `BackupService.importFromPath(path)`: lê o JSON diretamente do disco, validando existência do arquivo (retorna `-1` quando o caminho é inválido) e reaproveitando o pipeline de `importFromString`.
- **Sheet de Backup** redesenhado: campo de texto com ícone de pasta para o caminho do arquivo, botão "Colar caminho" no suffix (puxa da área de transferência), botão principal **Importar do caminho** e fallback secundário **Ou importar da área de transferência**.
- Hint com exemplo de path Android (`/storage/emulated/0/Download/constanza-backup.json`) e mensagens de erro específicas para arquivo inexistente vs. formato inválido.
- Sem novas dependências — usa `dart:io File` já disponível via `backup_service.dart`.

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
