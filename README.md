# Nosso Tempo V3 — Vida Compartilhada

## Para atualizar seu site atual

Você JÁ tem o Supabase e o GitHub Pages funcionando, então não precisa recriar nada.

### 1. Primeiro rode a migração no Supabase

1. Abra o projeto atual no Supabase.
2. Entre em **SQL Editor**.
3. Abra `MIGRACAO_V3.sql` deste ZIP.
4. Copie tudo e clique em **Run**.
5. Espere aparecer `Success`.

A migração preserva as atividades que já existem e libera várias atividades no mesmo dia.

### 2. Depois atualize o GitHub

Substitua no seu repositório:
- `index.html`
- `style.css`
- `app.js`
- `config.js`
- `service-worker.js`
- `manifest.webmanifest`
- `icon.svg`

Não precisa subir `MIGRACAO_V3.sql` se não quiser.

Depois do deploy, use `Ctrl + F5` no computador. No celular, feche e abra novamente. Se o PWA antigo persistir, abra o site no navegador primeiro para atualizar o Service Worker.

## O que entrou

### 📅 Calendário
- várias atividades no mesmo dia;
- opção de tempo bom e tempo ruim;
- horário;
- quem escolheu;
- participantes;
- aviso de conflito com aula/trabalho/disponibilidade;
- checklist dentro da atividade;
- realizado;
- imprevisto;
- datas passadas não marcadas entram como não realizadas no resumo.

### ✅ Checklist
- tarefas independentes do calendário;
- prazo;
- responsável;
- realizado;
- imprevisto;
- filtro de vencidas/não realizadas.

### 💰 Banquinho
- entradas;
- gastos;
- mercado, gás, pets, casa, contas etc.;
- marcar pago/comprado/recebido;
- entradas recebidas;
- gastos pagos;
- pendentes;
- sobra atual;
- sobra projetada depois dos pendentes.

### 🐾 Pets
O banco cria automaticamente:
- Simba — gato rajado;
- Nala — gato preto;
- Gris — gato cinza;
- Xayah — gata rajada.

Rotina padrão:
- comida;
- água;
- caixa de areia;
- carinho/brincadeira;
- cuidados extras personalizados.

### 💌 Recados
- mural compartilhado;
- prioridade normal/importante;
- recados não lidos aparecem ao entrar;
- badge no sino;
- Realtime;
- notificação do navegador se autorizada.

### 📊 Resumo
- atividades realizadas;
- não realizadas;
- imprevistos;
- checklists;
- cuidados dos pets;
- finanças.

### 👤 Perfil e disponibilidade
Cada pessoa pode cadastrar:
- nome;
- cor;
- recado de perfil;
- trabalho;
- aula;
- período ocupado;
- período disponível;
- exceção para uma data específica.

Ao marcar uma atividade, o editor mostra mensagens como:
- `Nat: ocupado — aula`
- `Seedy: disponível — noite livre`

## Regra de não realizado

O sistema calcula assim:
- marcou **Realizamos** → realizado;
- marcou **Imprevisto** → imprevisto;
- a data passou e ficou planejada → não realizado;
- hoje ou futuro → planejado.

Isso não apaga nem altera o histórico automaticamente.
