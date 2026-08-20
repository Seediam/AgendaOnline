# Nosso Tempo V5 — Painel da Casa

## Antes de subir no GitHub

Você já está na V4. **Não apague o projeto nem as tabelas do Supabase.**

1. Abra o projeto atual no **Supabase**.
2. Vá em **SQL Editor**.
3. Abra `MIGRACAO_V5.sql`.
4. Copie tudo e clique em **Run**.
5. Confirme `Success`.
6. Só depois substitua os arquivos no GitHub Pages.

Arquivos para substituir:
- `index.html`
- `style.css`
- `app.js`
- `service-worker.js`
- `manifest.webmanifest`

Mantenha seu `config.js` atual, porque ele já tem a URL e a Publishable Key corretas.

Depois do GitHub publicar:
- computador: `Ctrl + F5`;
- celular: feche e abra o site novamente;
- se o atalho instalado insistir na versão antiga, remova o atalho e adicione novamente.

---

# O que entrou na V5

## 🏠 Página Hoje

É a nova tela inicial.

Ela reúne:
- atividades de hoje;
- tarefas e rotinas que acontecem hoje;
- progresso diário dos quatro pets;
- contas atrasadas ou dentro do período de aviso;
- horários disponíveis/ocupados de cada pessoa;
- estoque baixo;
- saúde dos pets próxima;
- metas perto do prazo.

A ideia é não precisar abrir seis páginas para descobrir o que merece atenção naquele dia.

---

## 💸 Contas recorrentes

No Banquinho existe `+ Conta recorrente`.

Você cadastra:
- aluguel;
- internet;
- luz;
- assinaturas;
- plano;
- qualquer gasto mensal.

Campos:
- valor;
- dia do vencimento;
- responsável;
- mês inicial;
- mês final opcional;
- quantos dias antes avisar.

Exemplo:
`Internet — R$ 120 — vence dia 23 — avisar 3 dias antes`

A partir do dia 20 aparece:
`Vence em 3d`

Se passar:
`Atrasada 2d`

Ao marcar paga:
1. o mês fica marcado como pago;
2. um gasto pago é criado automaticamente no Banquinho.

Se desmarcar, o lançamento automático também é removido.

---

## 🛒 Lista de compras

Cada item pode ter:
- quantidade;
- categoria;
- responsável;
- preço estimado;
- observação.

Ao marcar `Comprado ✓`:
- o item é concluído;
- se houver preço estimado, o site cria um gasto pago no Banquinho.

Exemplo:
`Areia dos gatos • 2 pacotes • Nat • ≈ R$ 42`

---

## 🐾 Saúde dos pets

Além da rotina diária, agora existe a seção Saúde.

Pets já usados pelo projeto:
- Simba;
- Nala;
- Gris;
- Xayah.

Registros disponíveis:
- 💉 vacina;
- 💊 vermífugo;
- 🪲 antipulgas;
- 🩺 veterinário;
- ⚖️ peso;
- 💊 medicamento;
- ✨ outro.

Um registro pode guardar:
- data;
- próxima data;
- peso;
- dose;
- detalhes.

Próximas datas aparecem nos alertas da página Hoje.

---

## 🎯 Metas

Crie metas de:
- dinheiro;
- quantidade;
- percentual.

Exemplos:
- Juntar R$ 5.000 para viagem;
- Fazer 12 caminhadas no mês;
- Organizar 5 cômodos;
- Completar 100% de uma reforma.

Cada meta tem barra de progresso e botão `Adicionar`.

Ao atingir o objetivo, vira concluída automaticamente.

---

## 📦 Estoque da casa

Cadastre:
- gás;
- areia dos gatos;
- ração;
- produto de limpeza;
- papel higiênico;
- comida;
- qualquer item.

Para cada item:
- quantidade atual;
- quantidade mínima;
- unidade.

Quando:
`quantidade atual <= mínimo`

o sistema mostra:
`⚠ Está acabando`

E aparece o botão:
`🛒 Comprar`

Ele adiciona o item diretamente na Lista de Compras, evitando duplicar o mesmo item pendente.

---

## 🕒 Duração das atividades e conflitos reais

As atividades agora têm:
- horário inicial;
- horário final.

A checagem compara o intervalo completo.

Exemplo:

Perfil:
`Nat — Aula — 18:30 até 21:30`

Nova atividade:
`Jantar — 20:00 até 22:00`

Resultado:
`Nat: ocupado — aula (18:30–21:30)`

Também detecta conflito com outra atividade do próprio calendário.

---

## 📆 Exceções em rotinas

Dentro de uma tarefa recorrente existe:

`Pular datas específicas`

Exemplo:
`Limpar a casa — toda segunda`

Adicionar exceção:
`07/09 — feriado`

A rotina:
- continua nas outras segundas;
- não aparece em 07/09;
- essa data não conta como “não realizada”.

Você pode adicionar várias exceções sem apagar a rotina.

---

## 💌 Recados e notificações

Os recados continuam:
- sincronizados;
- aparecendo ao entrar;
- com badge no sino.

Agora contas dentro do prazo de alerta também mostram aviso quando o app é aberto. Se a permissão de notificações do navegador estiver ativa, o navegador também pode mostrar esse alerta.

---

## Banco de dados

A V5 adiciona:
- `shared_task_exceptions`
- `recurring_bills`
- `recurring_bill_payments`
- `shopping_items`
- `pet_health_records`
- `goals`
- `inventory_items`
- `end_time` em `day_plans`

Tudo usa RLS e continua restrito aos membros da mesma agenda.

Nunca coloque uma `service_role` ou `sb_secret_...` no GitHub.
Use somente a Publishable Key no `config.js`.
