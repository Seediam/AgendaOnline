# Nosso Tempo — Calendário compartilhado

Este projeto é um site estático em HTML/CSS/JS pensado para duas pessoas planejarem um período juntas.

## O que já está pronto

- Calendário com período personalizado (ex.: 20/08 até 20/09).
- Duas opções por dia:
  - ☀️ se o tempo estiver bom;
  - 🌧️ se o tempo estiver ruim.
- Horário.
- Categoria (tempo juntos, movimento, lazer, casa, trabalho/projeto, cuidado etc.).
- Quem escolhe o dia.
- Status: planejado, realizado ou não rolou.
- Anotações.
- Lembrete no navegador.
- Exportação `.ics` para adicionar o compromisso ao calendário do celular/computador.
- Previsão do tempo para Cascatinha, Petrópolis/RJ.
- 6 paletas pastel; cada pessoa pode deixar uma cor diferente no próprio aparelho.
- Banco online compartilhado usando Supabase.
- Atualização em tempo real quando a outra pessoa altera um dia.
- Código de convite para entrar na mesma agenda.
- Modo demonstração local caso você ainda não tenha configurado o banco.

---

# 1. Testar agora, sem banco

Abra `index.html`.

Como `config.js` vem sem as chaves do Supabase, o site entra em **Modo demonstração local**.

Nesse modo:
- tudo funciona visualmente;
- seus dados ficam salvos no navegador;
- a outra pessoa ainda NÃO enxerga suas alterações.

Se o navegador bloquear alguma função por você ter aberto como `file://`, rode o arquivo `ABRIR_SITE.bat` no Windows. Ele abre um servidor local na porta 8080.

---

# 2. Criar o banco gratuito no Supabase

1. Entre em **supabase.com** e crie uma conta.
2. Clique em **New project**.
3. Escolha um nome, uma senha forte para o banco e a região.
4. Aguarde o projeto ficar pronto.
5. No menu do projeto, abra **SQL Editor**.
6. Clique em uma nova query.
7. Abra o arquivo `supabase.sql` deste ZIP.
8. Copie TODO o conteúdo.
9. Cole no SQL Editor.
10. Clique em **Run**.

Isso cria:
- agendas;
- membros;
- planos dos dias;
- permissões;
- código de convite;
- sincronização Realtime.

---

# 3. Pegar URL e chave do Supabase

No painel do Supabase:

1. Abra **Project Settings / API** (a posição do menu pode mudar com atualizações do painel).
2. Copie o **Project URL**.
3. Copie a **Publishable key**. Se seu painel ainda mostrar `anon public`, ela também serve para este projeto.
4. Abra `config.js`.
5. Preencha assim:

```js
window.APP_CONFIG = {
  SUPABASE_URL: "https://SEU-PROJETO.supabase.co",
  SUPABASE_KEY: "SUA_CHAVE_PUBLICA",
  WEATHER_LATITUDE: -22.47203,
  WEATHER_LONGITUDE: -43.14837,
  WEATHER_LABEL: "Cascatinha • Petrópolis"
};
```

IMPORTANTE:
- A chave pública/publishable pode ficar no front-end.
- NUNCA coloque `service_role` no site.

---

# 4. Login das duas pessoas

O projeto usa login por e-mail e senha.

Pessoa 1:
1. cria uma conta no site;
2. cria a agenda;
3. o site mostra um código de convite.

Pessoa 2:
1. cria a própria conta;
2. escolhe “Entrar com convite”;
3. coloca o código;
4. pronto — ambos editam a mesma agenda.

Se o Supabase pedir confirmação por e-mail, cada pessoa precisa confirmar antes de entrar.

Para testes privados, você também pode verificar em **Authentication** as configurações de confirmação de e-mail do seu projeto.

---

# 5. Clima

O site usa Open‑Meteo sem chave de API.

Local configurado:
- Cascatinha, Petrópolis/RJ
- latitude: -22.47203
- longitude: -43.14837

O calendário tenta mostrar:
- emoji do clima;
- temperatura máxima/mínima;
- chance de chuva.

A previsão futura é limitada ao período disponibilizado pelo serviço. Datas mais distantes aparecem sem previsão até chegarem mais perto.

---

# 6. Lembretes

Existem dois jeitos:

## Aviso dentro do navegador
Clique no sino 🔔 e autorize notificações.

Limitação: navegadores comuns não garantem que uma página totalmente fechada acorde sozinha no horário. Por isso, o aviso é confiável enquanto o site estiver aberto.

## Arquivo .ics
Dentro de qualquer dia, clique em **Baixar lembrete .ics**.

Você pode abrir esse arquivo no:
- Google Calendar;
- calendário do Android;
- iPhone;
- Outlook;
- Windows.

O evento é criado com um aviso de 30 minutos antes.

---

# 7. Publicar de graça

Como este projeto é estático, você pode publicar em serviços gratuitos de hospedagem estática, por exemplo:
- GitHub Pages;
- Netlify;
- Vercel;
- Cloudflare Pages.

Você só precisa subir estes arquivos:
- `index.html`
- `style.css`
- `app.js`
- `config.js`

O arquivo `supabase.sql` e o README não precisam ficar públicos.

Depois que estiver publicado, os dois podem acessar pelo celular e computador.

---

# 8. Como usar a lógica de vocês

Exemplo de um dia:

**Quem escolhe:** Pessoa A

**Se tempo bom**
> correr/caminhar: correr um pouco e caminhar o restante para pegar ritmo.

**Se tempo ruim**
> ler juntos ou jogar alguma coisa.

No outro dia, deixem a Pessoa B escolher as duas opções.

Na faixa “Equilíbrio do período”, o site conta quantos dias cada pessoa ficou responsável por escolher.

---

# Segurança

O banco usa Row Level Security (RLS).

Cada agenda possui um código de convite e somente usuários autenticados que entraram naquela agenda conseguem ler e editar os planos.

Não compartilhe o código publicamente.

---

# Arquivos

- `index.html` — estrutura do site.
- `style.css` — visual pastel e responsivo.
- `app.js` — calendário, clima, Supabase, lembretes e interação.
- `config.js` — suas chaves e localização.
- `supabase.sql` — configuração completa do banco.
- `ABRIR_SITE.bat` — servidor local simples para Windows.


---

## Atualização Mobile 2.0

No celular o calendário agora usa uma visualização compacta de 7 colunas, inspirada no comportamento de calendários móveis:

- os 7 dias da semana ficam sempre visíveis;
- cada compromisso aparece como uma faixa curta dentro do dia;
- toque em qualquer dia para abrir o editor;
- o editor abre como um painel pela parte inferior;
- botões `‹`, `Hoje` e `›` mudam rapidamente o período;
- o botão flutuante `+` abre o dia atual;
- o topo e os dias da semana ficam fixos durante a rolagem;
- inputs têm área de toque maior e evitam zoom involuntário no iPhone.

### Instalar no celular

Depois de publicar o site em HTTPS:

**Android / Chrome**
1. Abra o site.
2. Menu `⋮`.
3. `Adicionar à tela inicial` ou `Instalar app`.

**iPhone / Safari**
1. Abra o site.
2. Compartilhar.
3. `Adicionar à Tela de Início`.

O projeto inclui `manifest.webmanifest`, ícone e service worker. Os dados do Supabase e a previsão do tempo continuam exigindo internet.
