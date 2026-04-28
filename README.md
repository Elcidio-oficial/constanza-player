# Constanza Player

**Constanza Player** é um reprodutor de mídia moderno e intuitivo, desenvolvido para oferecer uma experiência de áudio e vídeo fluida e elegante. O foco do projeto é a simplicidade de uso aliada a uma interface limpa.

![License](https://img.shields.io/github/license/Elcidio-oficial/constanza-player)
![Stars](https://img.shields.io/github/stars/Elcidio-oficial/constanza-player)
![Issues](https://img.shields.io/github/issues/Elcidio-oficial/constanza-player)

---

## Funcionalidades

O player foi projetado para oferecer uma experiência imersiva, combinando estética moderna com ferramentas avançadas de personalização.

### Experiência Visual e Interface

- **Modo Foco / Minimalista:** interface simplificada que oculta controles secundários, destacando apenas a arte do álbum para uma experiência sem distrações.
- **Suporte a Metadados e Capas:** extração automática de capas de álbuns e leitura de tags ID3 (artista, álbum, ano) para manter sua biblioteca organizada.

### Controle de Áudio e Reprodução

- **Equalizador Integrado:** ajuste fino de frequências para personalizar a saída de áudio de acordo com seu hardware.
  - Grave
  - Médio
  - Agudo

- **Modos de Reprodução:**
  - **Shuffle:** ordem aleatória inteligente.
  - **Repeat One:** repete a faixa atual.
  - **Repeat All:** repete toda a playlist.

- **Letras Sincronizadas:** suporte a arquivos de legenda para visualização de letras em tempo real durante a reprodução.

### Performance e Atalhos

- **Atalhos de Teclado:** controle total sem tirar as mãos do teclado.

| Tecla              | Ação                   |
|-------------------|------------------------|
| `Espaço`          | Play / Pause           |
| `Seta Dir/Esq`    | Avançar / Retroceder   |
| `Seta Cima/Baixo` | Aumentar / Diminuir volume |

- **Cache Inteligente:** algoritmo de pré-carregamento para faixas frequentes, garantindo reprodução instantânea e economia de recursos.

---

## Imagens do Constanza Player

### Interface e Reprodução

<p align="center">
  <img src="https://github.com/user-attachments/assets/63cbcc86-93d9-47b6-bd84-c1a58c250b75" width="250"/>
  <img src="https://github.com/user-attachments/assets/a92a4aa6-05f9-452c-8d8a-886aabb0d1dd" width="250"/>
  <img src="https://github.com/user-attachments/assets/f33bb2e5-ace1-47bd-98e5-79462ce30ed8" width="250"/>
  <img src="https://github.com/user-attachments/assets/1805d969-0e00-44a4-8e2d-d6b96da995b0" width="250"/>
  <img src="https://github.com/user-attachments/assets/358726fb-52ed-48d8-a3c6-a947a0c23f1b" width="250"/>
  <img src="https://github.com/user-attachments/assets/58541476-a7c7-4ea3-922d-1487d2f59d23" width="250"/>
</p>

---

### Navegação e Configurações

<p align="center">
  <img src="https://github.com/user-attachments/assets/3949db69-bbd2-4650-a9af-6cebd9920395" width="250"/>
  <img src="https://github.com/user-attachments/assets/eb3c6f43-bb98-43b4-b795-bd48d2b7e35c" width="250"/>
  <img src="https://github.com/user-attachments/assets/36087c28-62cd-4314-801b-b18211cb1a08" width="250"/>
  <img src="https://github.com/user-attachments/assets/69053cb1-cef6-47f5-8f45-9ec6abbee5d3" width="250"/>
  <img src="https://github.com/user-attachments/assets/6ba675f5-9cb8-4be5-bad3-37812a256697" width="250"/>
  <img src="https://github.com/user-attachments/assets/fae48eca-4d4e-4961-aa29-e48826f340f8" width="250"/>
  <img src="https://github.com/user-attachments/assets/928da321-9826-4964-b650-66ac372dce4d" width="250"/>
</p>

## Arquitetura

Clean Architecture em 4 camadas:

```
lib/
├── core/             constants, theme, router, utils
├── domain/           entities (Song, Album, Artist, LyricLine, ...)
├── services/         audio_handler, scanner, storage, share, crash, backup
└── presentation/
    ├── pages/        UI por feature (home, library, now_playing, settings…)
    ├── providers/    Riverpod StateNotifiers (player, library, theme, artwork)
    └── widgets/      reusáveis (artwork_image, song_tile, mini_player…)
```

**Stack:** Flutter 3.41 · Material 3 · Riverpod 2 · go_router · just_audio + audio_service · on_audio_query · share_plus 11.

**Plataforma alvo:** Android (minSdk 24, targetSdk 35).

## Build

```bash
flutter pub get
flutter run                       # debug
flutter build apk --release       # APK assinado (chave de debug em sideload)
flutter build appbundle --release # AAB para Play Store (requer keystore)
```

### Signing release (para publicar)

1. Gere a keystore (uma vez — guarde com vida):
   ```bash
   keytool -genkey -v -keystore ~/constanza-release.jks \
     -keyalg RSA -keysize 2048 -validity 10000 -alias constanza
   ```
2. `cp android/key.properties.example android/key.properties` e preencha.
3. `flutter build appbundle --release` — usa a keystore automaticamente.

R8 + shrinkResources já estão ativos em release.

## Histórico

Veja [`update.md`](update.md) para o changelog completo.

## Credits
- BPM and musical key data powered by [GetSongBPM](https://getsongbpm.com)
