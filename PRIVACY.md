# Política de Privacidade — Constanza Músicas

**Última atualização:** 29 de maio de 2026
**Aplicativo:** Constanza Músicas (`com.constanza.constanza_player`)
**Desenvolvedor:** Elcidio
**Contato:** elcidiocrisanto100@gmail.com

---

## Resumo em uma frase

O **Constanza Músicas** é um reprodutor de música local. Ele **não coleta, não armazena em servidores e não compartilha** nenhum dado pessoal seu. Toda a sua biblioteca, configurações, favoritos e histórico ficam **exclusivamente no seu dispositivo**.

---

## 1. Quais dados o app acessa

### 1.1 Arquivos de áudio do dispositivo
**Permissões:** `READ_MEDIA_AUDIO` (Android 13+) e `READ_EXTERNAL_STORAGE` (Android 12 ou anterior).

- Acessamos apenas para **listar e tocar** as músicas já armazenadas no seu aparelho.
- Lemos metadados (título, artista, álbum, capa, letras embutidas) **localmente**.
- **Nenhum arquivo ou metadado é enviado para fora do dispositivo.**

### 1.2 Imagens escolhidas por você
**Permissão:** seletor de fotos do sistema (sem permissão extra no Android 13+).

- Usado apenas quando você manualmente escolhe uma imagem para definir como capa personalizada de uma música, álbum ou playlist.
- A imagem é copiada para o armazenamento privado do app e **nunca enviada para fora**.

### 1.3 Conexão com a Internet
**Permissão:** `INTERNET`.

Conexões externas acontecem **apenas** nestes casos:

- **Letras de música**: consultamos o serviço público e gratuito [LRCLIB](https://lrclib.net) enviando título e artista da faixa que você está tocando, para baixar a letra correspondente.
- **Fotos de artistas**: download eventual de imagens públicas de artistas para enriquecer a interface.
- **Cálculo de BPM/tonalidade**: pode usar serviços públicos quando você ativa a função manualmente.

**Em nenhum momento enviamos:** seu nome, e-mail, ID do aparelho, IP coletado por nós, endereço, telefone, contatos, lista de músicas, hábitos de escuta ou qualquer outra informação pessoal.

### 1.4 Notificações
**Permissão:** `POST_NOTIFICATIONS` (Android 13+).

- Usada **apenas** para exibir os controles de mídia (play/pause/próxima) na barra de notificação e na tela de bloqueio durante a reprodução.

### 1.5 Reprodução em segundo plano
**Permissões:** `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MEDIA_PLAYBACK`, `WAKE_LOCK`.

- Permitem que a música continue tocando com a tela apagada ou o app fora de foco.
- Não fazem nenhuma coleta de dados.

### 1.6 Otimização de bateria (opcional)
**Permissão:** `REQUEST_IGNORE_BATTERY_OPTIMIZATIONS`.

- Solicitada **somente** se você ativar manualmente nas configurações do app, para evitar que o sistema Android pause o áudio em segundo plano em alguns aparelhos.
- Você pode revogar a qualquer momento nas configurações do Android.

---

## 2. Relatório de erros (crashes)

Se o app fechar inesperadamente, salvamos um registro técnico do erro (mensagem e stack trace) em um arquivo chamado `crashes.jsonl` dentro do **armazenamento privado do app**, no seu próprio aparelho.

- Esses registros **nunca são enviados automaticamente** para nós nem para terceiros.
- Você pode visualizar e apagar os logs nas configurações do app.
- Os arquivos são removidos automaticamente quando você desinstala o app.

---

## 3. O que **não** fazemos

- ❌ Não temos cadastro, login ou conta de usuário.
- ❌ Não exibimos publicidade.
- ❌ Não usamos Google Analytics, Firebase Analytics nem qualquer serviço de rastreamento.
- ❌ Não vendemos, alugamos ou compartilhamos dados.
- ❌ Não integramos com redes sociais.
- ❌ Não usamos cookies, SDKs de marketing nem fingerprinting.

---

## 4. Crianças

O app é classificado como adequado para todos os públicos e **não coleta dados de nenhuma faixa etária**, incluindo menores de 13 anos. Estamos em conformidade com a COPPA e a LGPD.

---

## 5. Seus direitos (LGPD / GDPR)

Como **nenhum dado pessoal seu sai do dispositivo**, não há informações para solicitar, corrigir ou apagar em nossos servidores — não temos servidores. Para apagar tudo, basta desinstalar o aplicativo: todos os dados (biblioteca, favoritos, histórico, crashes, configurações) são removidos com a desinstalação.

---

## 6. Serviços de terceiros mencionados

| Serviço | Finalidade | Política deles |
|---------|-----------|----------------|
| LRCLIB (lrclib.net) | Busca de letras | https://lrclib.net |
| Google Play Services | Distribuição do app | https://policies.google.com/privacy |

Nenhum desses serviços recebe informações pessoais suas por meio do nosso app — apenas os parâmetros mínimos para a função técnica (ex.: título + artista da faixa para LRCLIB).

---

## 7. Mudanças nesta política

Eventuais atualizações serão refletidas neste documento, com a data de "Última atualização" no topo. Mudanças significativas serão comunicadas dentro do próprio aplicativo na próxima abertura após a atualização.

---

## 8. Contato

Dúvidas, sugestões ou solicitações relacionadas à privacidade:

**E-mail:** elcidiocrisanto100@gmail.com

---

*Esta política se aplica exclusivamente ao aplicativo Constanza Músicas distribuído pela Google Play Store sob o pacote `com.constanza.constanza_player`.*
