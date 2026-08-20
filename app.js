/* Nosso Tempo — app.js */
(() => {
  "use strict";

  const CONFIG = window.APP_CONFIG || {};
  const SUPABASE_READY = Boolean(CONFIG.SUPABASE_URL && CONFIG.SUPABASE_KEY && window.supabase);
  const WEATHER_LAT = CONFIG.WEATHER_LATITUDE ?? -22.47203;
  const WEATHER_LON = CONFIG.WEATHER_LONGITUDE ?? -43.14837;

  const $ = (sel) => document.querySelector(sel);
  const $$ = (sel) => [...document.querySelectorAll(sel)];

  const state = {
    mode: SUPABASE_READY ? "online" : "demo",
    supabase: null,
    session: null,
    user: null,
    board: null,
    boards: [],
    members: [],
    plans: new Map(),
    weather: new Map(),
    activeDate: null,
    authMode: "login",
    realtimeChannel: null,
    rangeStart: null,
    rangeEnd: null
  };

  const themes = [
    { id: "peach", name: "Pêssego", vars: { bg:"#fffaf7", surface:"#ffffff", surface2:"#fff1eb", primary:"#df8f7c", primaryDark:"#b86757", secondary:"#f3c9bc", accent:"#dbe9d5", accent2:"#dcd6f0", text:"#433b3a", muted:"#837777", border:"#eaded9", good:"#d7ead0", bad:"#d8e6f4", done:"#eed9a8" } },
    { id: "lavender", name: "Lavanda", vars: { bg:"#fbf9ff", surface:"#ffffff", surface2:"#f1edfb", primary:"#9a86c5", primaryDark:"#715d9e", secondary:"#d8cff0", accent:"#dcebdc", accent2:"#f1dbe9", text:"#403b4b", muted:"#7e7789", border:"#e5dff0", good:"#dcebd8", bad:"#dfe6f5", done:"#f0dfb6" } },
    { id: "mint", name: "Menta", vars: { bg:"#f8fdfb", surface:"#ffffff", surface2:"#eaf8f1", primary:"#78b99a", primaryDark:"#4d8c70", secondary:"#c8ead9", accent:"#f3dfc4", accent2:"#dfe1f5", text:"#34443e", muted:"#74857e", border:"#dcebe4", good:"#d9eddc", bad:"#dceaf4", done:"#f0e0b3" } },
    { id: "sky", name: "Céu", vars: { bg:"#f8fbff", surface:"#ffffff", surface2:"#eaf3fb", primary:"#7caacb", primaryDark:"#527e9e", secondary:"#cce1f0", accent:"#e1ead1", accent2:"#eadcf0", text:"#35434e", muted:"#74818a", border:"#dbe8f0", good:"#dcebd8", bad:"#d7e8f5", done:"#efe0b5" } },
    { id: "rose", name: "Rosé", vars: { bg:"#fff9fb", surface:"#ffffff", surface2:"#fbeaf0", primary:"#cf819b", primaryDark:"#9f5b72", secondary:"#f0c7d4", accent:"#dcebd9", accent2:"#e5ddf3", text:"#493a40", muted:"#89747b", border:"#eedde3", good:"#dcebd8", bad:"#dce7f3", done:"#f0ddb2" } },
    { id: "vanilla", name: "Baunilha", vars: { bg:"#fffdf7", surface:"#ffffff", surface2:"#fbf2dc", primary:"#c49b61", primaryDark:"#92703f", secondary:"#eed8ad", accent:"#dce9d8", accent2:"#e1dded", text:"#463f35", muted:"#827b70", border:"#ebe2d2", good:"#dcebd6", bad:"#dde8f2", done:"#f0dea9" } }
  ];

  function toISODate(date) {
    const y = date.getFullYear();
    const m = String(date.getMonth()+1).padStart(2,"0");
    const d = String(date.getDate()).padStart(2,"0");
    return `${y}-${m}-${d}`;
  }

  function parseISODate(s) {
    const [y,m,d] = s.split("-").map(Number);
    return new Date(y, m-1, d);
  }

  function addDays(date, n) {
    const d = new Date(date);
    d.setDate(d.getDate()+n);
    return d;
  }

  function addMonths(date, n) {
    const d = new Date(date);
    const day = d.getDate();
    d.setDate(1);
    d.setMonth(d.getMonth()+n);
    const last = new Date(d.getFullYear(), d.getMonth()+1, 0).getDate();
    d.setDate(Math.min(day,last));
    return d;
  }

  function formatDateLong(iso) {
    return parseISODate(iso).toLocaleDateString("pt-BR", { day:"numeric", month:"long", year:"numeric" });
  }

  function formatWeekday(iso) {
    return parseISODate(iso).toLocaleDateString("pt-BR", { weekday:"long" });
  }

  function shortMonth(date) {
    return date.toLocaleDateString("pt-BR", { month:"short" }).replace(".", "");
  }

  function updateMobileRangeLabel() {
    const title = $("#mobileRangeTitle");
    const subtitle = $("#mobileRangeSubtitle");
    if (!title || !state.rangeStart || !state.rangeEnd) return;
    const start = parseISODate(state.rangeStart);
    const end = parseISODate(state.rangeEnd);

    if (start.getFullYear() === end.getFullYear()) {
      title.textContent = `${start.getDate()} ${shortMonth(start)} — ${end.getDate()} ${shortMonth(end)}`;
      subtitle.textContent = `${start.getFullYear()} • toque em um dia para editar`;
    } else {
      title.textContent = `${start.getDate()} ${shortMonth(start)} ${start.getFullYear()} — ${end.getDate()} ${shortMonth(end)} ${end.getFullYear()}`;
      subtitle.textContent = "toque em um dia para editar";
    }
  }

  async function applyRangeAndRefresh(startISO, endISO) {
    state.rangeStart = startISO;
    state.rangeEnd = endISO;
    $("#startDate").value = startISO;
    $("#endDate").value = endISO;
    updateMobileRangeLabel();

    if (state.mode === "online") await loadPlans();
    else loadDemoPlans();

    renderCalendar();
    updateStats();
    await loadWeather();
  }

  async function shiftCurrentPeriod(direction) {
    const start = parseISODate(state.rangeStart);
    const end = parseISODate(state.rangeEnd);
    const newStart = addMonths(start, direction);
    const newEnd = addMonths(end, direction);
    await applyRangeAndRefresh(toISODate(newStart), toISODate(newEnd));
  }

  async function goToTodayRange() {
    const now = new Date();
    await applyRangeAndRefresh(toISODate(now), toISODate(addMonths(now, 1)));
  }

  function escapeHTML(value="") {
    return String(value).replace(/[&<>"']/g, ch => ({ "&":"&amp;", "<":"&lt;", ">":"&gt;", '"':"&quot;", "'":"&#039;" }[ch]));
  }

  function toast(msg) {
    const el = $("#toast");
    el.textContent = msg;
    el.classList.add("show");
    clearTimeout(toast.timer);
    toast.timer = setTimeout(() => el.classList.remove("show"), 2600);
  }

  function setSync(text) {
    $("#syncStatus").textContent = text;
  }

  function showOnly(id) {
    ["#authScreen","#boardScreen","#app"].forEach(sel => $(sel).classList.add("hidden"));
    $(id).classList.remove("hidden");
  }

  function applyTheme(id) {
    const theme = themes.find(t => t.id === id) || themes[0];
    const root = document.documentElement;
    const mapping = {
      bg:"--bg", surface:"--surface", surface2:"--surface-2", primary:"--primary",
      primaryDark:"--primary-dark", secondary:"--secondary", accent:"--accent",
      accent2:"--accent-2", text:"--text", muted:"--muted", border:"--border",
      good:"--good", bad:"--bad", done:"--done"
    };
    Object.entries(theme.vars).forEach(([k,v]) => root.style.setProperty(mapping[k], v));
    localStorage.setItem("nosso_tempo_theme", theme.id);
  }

  function renderThemeOptions() {
    $("#themeOptions").innerHTML = themes.map(t => `
      <button class="theme-choice" data-theme="${t.id}">
        <span class="swatches">
          <i style="background:${t.vars.primary}"></i>
          <i style="background:${t.vars.surface2}"></i>
          <i style="background:${t.vars.accent2}"></i>
        </span>
        <span>${t.name}</span>
      </button>
    `).join("");
  }

  function defaultRange() {
    const today = new Date();
    state.rangeStart = toISODate(today);
    state.rangeEnd = toISODate(addMonths(today, 1));
    $("#startDate").value = state.rangeStart;
    $("#endDate").value = state.rangeEnd;
    updateMobileRangeLabel();
  }

  function getDateRange(start, end) {
    const dates = [];
    let current = parseISODate(start);
    const last = parseISODate(end);
    let guard = 0;
    while (current <= last && guard < 370) {
      dates.push(toISODate(current));
      current = addDays(current,1);
      guard++;
    }
    return dates;
  }

  function weatherIcon(code) {
    if (code === 0) return "☀️";
    if ([1,2].includes(code)) return "🌤️";
    if (code === 3) return "☁️";
    if ([45,48].includes(code)) return "🌫️";
    if ([51,53,55,56,57,61,63,65,66,67,80,81,82].includes(code)) return "🌧️";
    if ([71,73,75,77,85,86].includes(code)) return "❄️";
    if ([95,96,99].includes(code)) return "⛈️";
    return "🌥️";
  }

  function weatherLabel(code) {
    if (code === 0) return "céu limpo";
    if ([1,2].includes(code)) return "poucas nuvens";
    if (code === 3) return "nublado";
    if ([45,48].includes(code)) return "neblina";
    if ([51,53,55,56,57].includes(code)) return "garoa";
    if ([61,63,65,66,67,80,81,82].includes(code)) return "chuva";
    if ([71,73,75,77,85,86].includes(code)) return "frio / neve";
    if ([95,96,99].includes(code)) return "trovoadas";
    return "tempo variável";
  }

  function isBadWeather(w) {
    if (!w) return false;
    return (w.precip ?? 0) >= 50 || [51,53,55,56,57,61,63,65,66,67,80,81,82,95,96,99].includes(w.code);
  }

  async function loadWeather() {
    state.weather.clear();
    const today = new Date();
    const todayISO = toISODate(today);
    const maxForecast = toISODate(addDays(today, 15));

    let start = state.rangeStart < todayISO ? todayISO : state.rangeStart;
    let end = state.rangeEnd > maxForecast ? maxForecast : state.rangeEnd;

    if (start > end) {
      updateTodayWeather();
      renderCalendar();
      return;
    }

    try {
      const params = new URLSearchParams({
        latitude: WEATHER_LAT,
        longitude: WEATHER_LON,
        daily: "weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max",
        timezone: "America/Sao_Paulo",
        start_date: start,
        end_date: end
      });
      const res = await fetch(`https://api.open-meteo.com/v1/forecast?${params}`);
      if (!res.ok) throw new Error("Falha no clima");
      const data = await res.json();
      (data.daily?.time || []).forEach((date, i) => {
        state.weather.set(date, {
          code: data.daily.weather_code[i],
          max: Math.round(data.daily.temperature_2m_max[i]),
          min: Math.round(data.daily.temperature_2m_min[i]),
          precip: data.daily.precipitation_probability_max[i] ?? 0
        });
      });
    } catch (err) {
      console.warn(err);
    }
    updateTodayWeather();
    renderCalendar();
  }

  function updateTodayWeather() {
    const today = toISODate(new Date());
    const w = state.weather.get(today);
    if (!w) {
      $("#todayWeatherIcon").textContent = "🌥️";
      $("#todayWeatherTitle").textContent = "Previsão indisponível";
      $("#todayWeatherText").textContent = "O calendário continua funcionando normalmente.";
      return;
    }
    $("#todayWeatherIcon").textContent = weatherIcon(w.code);
    $("#todayWeatherTitle").textContent = `${w.max}° / ${w.min}° • ${weatherLabel(w.code)}`;
    $("#todayWeatherText").textContent = `${w.precip}% de chance de chuva hoje.`;
  }

  // -------------------- DEMO STORE --------------------
  function initDemo() {
    state.user = { id:"demo-user", email:"demo@local" };
    state.session = { user: state.user };
    state.board = { id:"demo-board", name:"Nosso Tempo", join_code:"LOCAL" };
    state.boards = [state.board];
    state.members = [
      { user_id:"demo-user", display_name:"Você" },
      { user_id:"demo-partner", display_name:"Outra pessoa" }
    ];
    $("#demoBanner").classList.remove("hidden");
    loadDemoPlans();
    enterApp();
  }

  function demoKey() {
    return "nosso_tempo_demo_plans";
  }

  function loadDemoPlans() {
    const raw = JSON.parse(localStorage.getItem(demoKey()) || "[]");
    state.plans = new Map(raw.map(p => [p.plan_date, p]));
  }

  function saveDemoPlans() {
    localStorage.setItem(demoKey(), JSON.stringify([...state.plans.values()]));
  }

  // -------------------- SUPABASE --------------------
  async function initOnline() {
    state.supabase = window.supabase.createClient(CONFIG.SUPABASE_URL, CONFIG.SUPABASE_KEY, {
      auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true }
    });

    const { data } = await state.supabase.auth.getSession();
    state.session = data.session;
    state.user = data.session?.user || null;

    state.supabase.auth.onAuthStateChange((_event, session) => {
      state.session = session;
      state.user = session?.user || null;
    });

    if (!state.user) {
      showOnly("#authScreen");
      return;
    }
    await loadBoards();
  }

  async function loadBoards() {
    const { data: memberships, error } = await state.supabase
      .from("board_members")
      .select("board_id, display_name")
      .eq("user_id", state.user.id);

    if (error) {
      console.error(error);
      toast("Não consegui carregar suas agendas.");
      return;
    }

    if (!memberships?.length) {
      state.boards = [];
      renderExistingBoards();
      showOnly("#boardScreen");
      return;
    }

    const ids = memberships.map(m => m.board_id);
    const { data: boards, error: bErr } = await state.supabase
      .from("boards")
      .select("id,name,join_code,created_at")
      .in("id", ids);

    if (bErr) {
      console.error(bErr);
      toast("Erro ao carregar agendas.");
      return;
    }

    state.boards = boards || [];
    const last = localStorage.getItem("nosso_tempo_board_id");
    const chosen = state.boards.find(b => b.id === last) || state.boards[0];
    if (chosen) {
      await selectBoard(chosen);
    } else {
      renderExistingBoards();
      showOnly("#boardScreen");
    }
  }

  async function selectBoard(board) {
    state.board = board;
    localStorage.setItem("nosso_tempo_board_id", board.id);
    await Promise.all([loadMembers(), loadPlans()]);
    subscribeRealtime();
    enterApp();
  }

  async function loadMembers() {
    const { data, error } = await state.supabase
      .from("board_members")
      .select("user_id,display_name,joined_at")
      .eq("board_id", state.board.id)
      .order("joined_at", { ascending:true });

    if (!error) state.members = data || [];
  }

  async function loadPlans() {
    setSync("sincronizando...");
    const { data, error } = await state.supabase
      .from("day_plans")
      .select("*")
      .eq("board_id", state.board.id)
      .gte("plan_date", state.rangeStart)
      .lte("plan_date", state.rangeEnd);

    if (error) {
      console.error(error);
      setSync("erro ao sincronizar");
      toast("Não consegui carregar o calendário.");
      return;
    }

    state.plans = new Map((data || []).map(p => [p.plan_date, p]));
    setSync("sincronizado agora");
  }

  function subscribeRealtime() {
    if (!state.supabase || !state.board) return;
    if (state.realtimeChannel) state.supabase.removeChannel(state.realtimeChannel);

    state.realtimeChannel = state.supabase
      .channel(`plans-${state.board.id}`)
      .on("postgres_changes", {
        event: "*",
        schema: "public",
        table: "day_plans",
        filter: `board_id=eq.${state.board.id}`
      }, async () => {
        await loadPlans();
        renderCalendar();
        updateStats();
      })
      .subscribe();
  }

  async function savePlanOnline(plan) {
    const payload = {
      board_id: state.board.id,
      plan_date: plan.plan_date,
      chooser_user_id: plan.chooser_user_id || null,
      category: plan.category,
      good_option: plan.good_option || null,
      bad_option: plan.bad_option || null,
      start_time: plan.start_time || null,
      selected_option: plan.selected_option,
      status: plan.status,
      reminder_at: plan.reminder_at || null,
      notes: plan.notes || null,
      updated_by: state.user.id,
      updated_at: new Date().toISOString()
    };
    const { data, error } = await state.supabase
      .from("day_plans")
      .upsert(payload, { onConflict:"board_id,plan_date" })
      .select()
      .single();
    if (error) throw error;
    state.plans.set(data.plan_date, data);
  }

  async function deletePlanOnline(date) {
    const { error } = await state.supabase
      .from("day_plans")
      .delete()
      .eq("board_id", state.board.id)
      .eq("plan_date", date);
    if (error) throw error;
    state.plans.delete(date);
  }

  // -------------------- UI --------------------
  function enterApp() {
    $("#appTitle").textContent = state.board?.name || "Nosso Tempo";
    $("#inviteCode").textContent = state.board?.join_code || "LOCAL";
    showOnly("#app");
    renderChooserOptions();
    renderCalendar();
    updateStats();
    loadWeather();
    checkReminders();
  }

  function renderExistingBoards() {
    const wrap = $("#existingBoards");
    if (!state.boards.length) {
      wrap.innerHTML = "";
      return;
    }
    wrap.innerHTML = `<p class="eyebrow">SUAS AGENDAS</p>` + state.boards.map(b => `
      <button class="existing-board" data-board-id="${b.id}">
        <span><strong>${escapeHTML(b.name)}</strong><br><small class="muted">código ${escapeHTML(b.join_code)}</small></span>
        <span>→</span>
      </button>
    `).join("");
  }

  function renderChooserOptions(selected="") {
    const options = state.members.map(m => `
      <option value="${m.user_id}" ${m.user_id === selected ? "selected":""}>${escapeHTML(m.display_name)}</option>
    `).join("");
    $("#chooserSelect").innerHTML = `<option value="">Ainda não definido</option>${options}`;
  }

  function memberName(id) {
    return state.members.find(m => m.user_id === id)?.display_name || "Sem responsável";
  }

  function updateStats() {
    const counts = Object.fromEntries(state.members.map(m => [m.user_id, 0]));
    [...state.plans.values()].forEach(p => {
      if (p.chooser_user_id && counts[p.chooser_user_id] !== undefined) counts[p.chooser_user_id]++;
    });
    $("#memberStats").innerHTML = state.members.map(m =>
      `<span class="member-pill">${escapeHTML(m.display_name)} • ${counts[m.user_id] || 0} dia(s)</span>`
    ).join("");
    if (state.members.length >= 2) {
      const values = state.members.map(m => counts[m.user_id] || 0);
      const diff = Math.max(...values) - Math.min(...values);
      $("#balanceTitle").textContent = diff <= 1 ? "Está bem equilibrado ♡" : "Talvez seja a vez de quem escolheu menos";
    }
  }

  function renderCalendar() {
    if (!state.rangeStart || !state.rangeEnd) return;
    updateMobileRangeLabel();

    const dates = getDateRange(state.rangeStart, state.rangeEnd);
    const first = parseISODate(state.rangeStart);
    const blankCount = (first.getDay() + 6) % 7; // segunda = 0
    const blanks = Array.from({length: blankCount}, () => `<div class="blank-day"></div>`).join("");
    const today = toISODate(new Date());

    const cards = dates.map(date => {
      const d = parseISODate(date);
      const plan = state.plans.get(date);
      const w = state.weather.get(date);
      const isDone = plan?.status === "done";
      const weekdayShort = d.toLocaleDateString("pt-BR",{weekday:"short"}).replace(".","");
      const weatherHTML = w
        ? `<span class="weather-mini" title="${escapeHTML(weatherLabel(w.code))}">${weatherIcon(w.code)} <span>${w.max}° • ${w.precip}%</span></span>`
        : `<span class="weather-mini" title="Previsão ainda indisponível">🗓️ <span>—</span></span>`;

      let content = `<div class="empty-copy">Clique para combinar as duas opções do dia.</div>`;
      if (plan) {
        const stateClass = plan.status === "done" ? "done" : plan.status === "skipped" ? "skipped" : "";
        const compactChooser = plan.chooser_user_id ? memberName(plan.chooser_user_id) : "";
        const compactTime = plan.start_time ? String(plan.start_time).slice(0,5) : "";
        content = `
          ${plan.chooser_user_id ? `<div class="chooser-chip">escolhe: ${escapeHTML(memberName(plan.chooser_user_id))}</div>` : ""}
          <div class="category-chip">${escapeHTML(plan.category || "💛 Tempo juntos")}</div>
          <div class="mobile-plan-meta"><i class="mobile-plan-state ${stateClass}"></i>${escapeHTML(compactTime)}${compactTime && compactChooser ? " • " : ""}${escapeHTML(compactChooser)}</div>
          <div class="plan-preview">
            ${plan.good_option ? `<div class="plan-line good" title="Tempo bom: ${escapeHTML(plan.good_option)}">☀ ${escapeHTML(plan.good_option)}</div>` : ""}
            ${plan.bad_option ? `<div class="plan-line bad" title="Tempo ruim: ${escapeHTML(plan.bad_option)}">☂ ${escapeHTML(plan.bad_option)}</div>` : ""}
          </div>
          ${plan.status === "done" ? `<span class="status-badge">✓ realizado</span>` : plan.status === "skipped" ? `<span class="status-badge">não rolou</span>` : ""}
          ${plan.start_time ? `<span class="time-badge">⏰ ${String(plan.start_time).slice(0,5)}</span>` : ""}
        `;
      }

      return `
        <article class="day-card ${date===today?"today":""} ${isDone?"done-card":""}" data-date="${date}">
          <div class="day-head">
            <span class="day-number"><strong>${d.getDate()}</strong><small>${weekdayShort}</small></span>
            ${weatherHTML}
          </div>
          ${content}
        </article>
      `;
    }).join("");

    $("#calendarGrid").innerHTML = blanks + cards;
  }

  function openPlanDialog(date) {
    state.activeDate = date;
    const plan = state.plans.get(date) || {
      plan_date: date, chooser_user_id:"", category:"💛 Tempo juntos",
      good_option:"", bad_option:"", start_time:"", selected_option:"auto",
      status:"planned", reminder_at:"", notes:""
    };

    $("#dialogWeekday").textContent = formatWeekday(date).toUpperCase();
    $("#dialogDate").textContent = formatDateLong(date);
    renderChooserOptions(plan.chooser_user_id || "");
    $("#category").value = plan.category || "💛 Tempo juntos";
    $("#goodOption").value = plan.good_option || "";
    $("#badOption").value = plan.bad_option || "";
    $("#planTime").value = plan.start_time ? String(plan.start_time).slice(0,5) : "";
    $("#selectedOption").value = plan.selected_option || "auto";
    $("#planStatus").value = plan.status || "planned";
    $("#notes").value = plan.notes || "";

    let reminder = "";
    if (plan.reminder_at) {
      const dt = new Date(plan.reminder_at);
      const local = new Date(dt.getTime() - dt.getTimezoneOffset()*60000);
      reminder = local.toISOString().slice(0,16);
    }
    $("#reminderAt").value = reminder;

    const w = state.weather.get(date);
    if (w) {
      const verdict = isBadWeather(w) ? "A previsão hoje favorece o plano de tempo ruim." : "A previsão hoje favorece o plano de tempo bom.";
      $("#dialogWeather").innerHTML = `${weatherIcon(w.code)} <strong>${w.max}° / ${w.min}°</strong> • ${w.precip}% de chuva • ${escapeHTML(weatherLabel(w.code))}. <span class="muted">${verdict}</span>`;
    } else {
      $("#dialogWeather").innerHTML = `🗓️ <span class="muted">A previsão ainda não está disponível para esta data. O Open‑Meteo costuma cobrir os próximos dias.</span>`;
    }

    $("#deletePlan").style.visibility = state.plans.has(date) ? "visible" : "hidden";
    $("#planDialog").showModal();
  }

  function formToPlan() {
    const reminderVal = $("#reminderAt").value;
    return {
      plan_date: state.activeDate,
      chooser_user_id: $("#chooserSelect").value || null,
      category: $("#category").value,
      good_option: $("#goodOption").value.trim(),
      bad_option: $("#badOption").value.trim(),
      start_time: $("#planTime").value || null,
      selected_option: $("#selectedOption").value,
      status: $("#planStatus").value,
      reminder_at: reminderVal ? new Date(reminderVal).toISOString() : null,
      notes: $("#notes").value.trim(),
      board_id: state.board?.id,
      updated_by: state.user?.id,
      updated_at: new Date().toISOString()
    };
  }

  async function saveActivePlan() {
    const plan = formToPlan();
    if (!plan.good_option && !plan.bad_option) {
      toast("Coloque pelo menos uma opção para o dia.");
      return false;
    }
    try {
      setSync("salvando...");
      if (state.mode === "demo") {
        state.plans.set(plan.plan_date, { ...plan, id: state.plans.get(plan.plan_date)?.id || crypto.randomUUID() });
        saveDemoPlans();
      } else {
        await savePlanOnline(plan);
      }
      setSync(state.mode === "demo" ? "salvo neste dispositivo" : "sincronizado agora");
      renderCalendar();
      updateStats();
      toast("Dia salvo ♡");
      return true;
    } catch (err) {
      console.error(err);
      setSync("erro ao salvar");
      toast(err.message || "Não consegui salvar.");
      return false;
    }
  }

  async function deleteActivePlan() {
    if (!state.activeDate || !state.plans.has(state.activeDate)) return;
    try {
      if (state.mode === "demo") {
        state.plans.delete(state.activeDate);
        saveDemoPlans();
      } else {
        await deletePlanOnline(state.activeDate);
      }
      renderCalendar();
      updateStats();
      $("#planDialog").close();
      toast("Dia apagado.");
    } catch (err) {
      console.error(err);
      toast("Não consegui excluir.");
    }
  }

  function downloadICSForPlan(plan) {
    const date = plan.plan_date.replaceAll("-","");
    const time = (plan.start_time || "19:00").replace(":","") + "00";
    const start = `${date}T${time}`;
    const endDate = new Date(parseISODate(plan.plan_date));
    const [hh,mm] = (plan.start_time || "19:00").split(":").map(Number);
    endDate.setHours(hh+1, mm, 0, 0);
    const end = `${toISODate(endDate).replaceAll("-","")}T${String(endDate.getHours()).padStart(2,"0")}${String(endDate.getMinutes()).padStart(2,"0")}00`;
    const selectedText = plan.selected_option === "good" ? plan.good_option
      : plan.selected_option === "bad" ? plan.bad_option
      : `Tempo bom: ${plan.good_option || "—"} | Tempo ruim: ${plan.bad_option || "—"}`;
    const description = (selectedText + (plan.notes ? ` | ${plan.notes}`:"")).replace(/\n/g," ").replace(/,/g,"\\,");
    const title = `${plan.category || "Nosso Tempo"} — ${state.board?.name || "Nosso Tempo"}`.replace(/,/g,"\\,");

    const ics = [
      "BEGIN:VCALENDAR",
      "VERSION:2.0",
      "PRODID:-//Nosso Tempo//PT-BR",
      "CALSCALE:GREGORIAN",
      "BEGIN:VEVENT",
      `UID:${crypto.randomUUID()}@nosso-tempo`,
      `DTSTAMP:${new Date().toISOString().replace(/[-:]/g,"").replace(/\.\d{3}Z/,"Z")}`,
      `DTSTART;TZID=America/Sao_Paulo:${start}`,
      `DTEND;TZID=America/Sao_Paulo:${end}`,
      `SUMMARY:${title}`,
      `DESCRIPTION:${description}`,
      "BEGIN:VALARM",
      "TRIGGER:-PT30M",
      "ACTION:DISPLAY",
      "DESCRIPTION:Lembrete Nosso Tempo",
      "END:VALARM",
      "END:VEVENT",
      "END:VCALENDAR"
    ].join("\r\n");

    const blob = new Blob([ics], {type:"text/calendar;charset=utf-8"});
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = `nosso-tempo-${plan.plan_date}.ics`;
    a.click();
    setTimeout(() => URL.revokeObjectURL(url), 1000);
  }

  async function requestNotifications() {
    if (!("Notification" in window)) {
      toast("Este navegador não oferece notificações.");
      return;
    }
    const result = await Notification.requestPermission();
    toast(result === "granted" ? "Lembretes ativados neste navegador." : "Notificações não foram autorizadas.");
  }

  function checkReminders() {
    if (!("Notification" in window) || Notification.permission !== "granted") return;
    const now = Date.now();
    const notified = new Set(JSON.parse(localStorage.getItem("nosso_tempo_notified") || "[]"));
    let changed = false;

    [...state.plans.values()].forEach(plan => {
      if (!plan.reminder_at || notified.has(plan.id)) return;
      const t = new Date(plan.reminder_at).getTime();
      if (t <= now && t >= now - 90_000) {
        const body = plan.selected_option === "bad" ? plan.bad_option
          : plan.selected_option === "good" ? plan.good_option
          : plan.good_option || plan.bad_option || "Vocês têm algo combinado.";
        new Notification("Nosso Tempo ♡", { body });
        notified.add(plan.id);
        changed = true;
      }
    });
    if (changed) localStorage.setItem("nosso_tempo_notified", JSON.stringify([...notified].slice(-200)));
  }

  // -------------------- EVENTS --------------------
  function bindEvents() {
    $$(".tab").forEach(btn => btn.addEventListener("click", () => {
      state.authMode = btn.dataset.authTab;
      $$(".tab").forEach(x => x.classList.toggle("active", x === btn));
      $("#authSubmit").textContent = state.authMode === "login" ? "Entrar" : "Criar conta";
      $("#authHint").textContent = state.authMode === "signup"
        ? "Depois do cadastro, talvez o Supabase peça confirmação por e-mail, dependendo da configuração do projeto."
        : "";
    }));

    $("#authForm").addEventListener("submit", async (e) => {
      e.preventDefault();
      if (!state.supabase) return;
      const email = $("#authEmail").value.trim();
      const password = $("#authPassword").value;
      try {
        if (state.authMode === "signup") {
          const { data, error } = await state.supabase.auth.signUp({ email, password });
          if (error) throw error;
          if (!data.session) {
            toast("Conta criada. Confirme o e-mail e depois entre.");
            state.authMode = "login";
            $$(".tab").forEach(x => x.classList.toggle("active", x.dataset.authTab === "login"));
            $("#authSubmit").textContent = "Entrar";
          } else {
            state.user = data.user; state.session = data.session; await loadBoards();
          }
        } else {
          const { data, error } = await state.supabase.auth.signInWithPassword({ email, password });
          if (error) throw error;
          state.user = data.user; state.session = data.session; await loadBoards();
        }
      } catch (err) {
        toast(err.message || "Não foi possível entrar.");
      }
    });

    $("#createBoardForm").addEventListener("submit", async (e) => {
      e.preventDefault();
      const name = $("#boardName").value.trim();
      const display = $("#creatorName").value.trim();
      const { data, error } = await state.supabase.rpc("create_board", { p_name:name, p_display_name:display });
      if (error) return toast(error.message);
      toast(`Agenda criada! Código ${data?.[0]?.join_code || ""}`);
      await loadBoards();
    });

    $("#joinBoardForm").addEventListener("submit", async (e) => {
      e.preventDefault();
      const code = $("#joinCode").value.trim();
      const display = $("#joinName").value.trim();
      const { error } = await state.supabase.rpc("join_board", { p_join_code:code, p_display_name:display });
      if (error) return toast(error.message);
      toast("Você entrou na agenda ♡");
      await loadBoards();
    });

    $("#existingBoards").addEventListener("click", async (e) => {
      const btn = e.target.closest("[data-board-id]");
      if (!btn) return;
      const board = state.boards.find(b => b.id === btn.dataset.boardId);
      if (board) await selectBoard(board);
    });

    $("#boardLogout").addEventListener("click", async () => {
      await state.supabase?.auth.signOut();
      state.user = null; state.session = null; showOnly("#authScreen");
    });

    $("#calendarGrid").addEventListener("click", (e) => {
      const card = e.target.closest(".day-card");
      if (card) openPlanDialog(card.dataset.date);
    });

    $("#planForm").addEventListener("submit", async (e) => {
      e.preventDefault();
      if (await saveActivePlan()) $("#planDialog").close();
    });

    $("#closeDialog").addEventListener("click", () => $("#planDialog").close());
    $("#deletePlan").addEventListener("click", deleteActivePlan);
    $("#downloadICS").addEventListener("click", () => downloadICSForPlan(formToPlan()));

    $("#applyRange").addEventListener("click", async () => {
      const s = $("#startDate").value, e = $("#endDate").value;
      if (!s || !e || s > e) return toast("Escolha um período válido.");
      const diff = Math.round((parseISODate(e)-parseISODate(s))/86400000);
      if (diff > 365) return toast("Escolha um período de até 1 ano.");
      await applyRangeAndRefresh(s, e);
    });

    $("#prevPeriod")?.addEventListener("click", () => shiftCurrentPeriod(-1));
    $("#nextPeriod")?.addEventListener("click", () => shiftCurrentPeriod(1));
    $("#todayButton")?.addEventListener("click", goToTodayRange);

    $("#mobileFab")?.addEventListener("click", () => {
      const today = toISODate(new Date());
      const target = today >= state.rangeStart && today <= state.rangeEnd ? today : state.rangeStart;
      openPlanDialog(target);
    });

    $("#themeButton").addEventListener("click", () => {
      $("#themePopover").classList.toggle("hidden");
      $("#menuPopover").classList.add("hidden");
    });
    $("#menuButton").addEventListener("click", () => {
      $("#menuPopover").classList.toggle("hidden");
      $("#themePopover").classList.add("hidden");
    });
    $$("[data-close-popover]").forEach(btn => btn.addEventListener("click", () => $("#" + btn.dataset.closePopover).classList.add("hidden")));

    $("#themeOptions").addEventListener("click", (e) => {
      const btn = e.target.closest("[data-theme]");
      if (!btn) return;
      applyTheme(btn.dataset.theme);
      $("#themePopover").classList.add("hidden");
    });

    $("#notifyButton").addEventListener("click", requestNotifications);

    $("#copyInvite").addEventListener("click", async () => {
      const code = state.board?.join_code || "LOCAL";
      try {
        await navigator.clipboard.writeText(code);
        toast("Código copiado.");
      } catch {
        toast(`Código: ${code}`);
      }
    });

    $("#switchBoard").addEventListener("click", () => {
      $("#menuPopover").classList.add("hidden");
      if (state.mode === "demo") return toast("No modo demonstração existe só uma agenda.");
      renderExistingBoards();
      showOnly("#boardScreen");
    });

    $("#logoutButton").addEventListener("click", async () => {
      $("#menuPopover").classList.add("hidden");
      if (state.mode === "demo") return toast("Modo demonstração local.");
      await state.supabase.auth.signOut();
      state.user = null; state.session = null; showOnly("#authScreen");
    });

    document.addEventListener("click", (e) => {
      if (!e.target.closest("#themePopover") && !e.target.closest("#themeButton")) $("#themePopover").classList.add("hidden");
      if (!e.target.closest("#menuPopover") && !e.target.closest("#menuButton")) $("#menuPopover").classList.add("hidden");
    });

    setInterval(checkReminders, 30_000);
  }

  async function boot() {
    applyTheme(localStorage.getItem("nosso_tempo_theme") || "peach");
    renderThemeOptions();
    defaultRange();
    bindEvents();

    if ("serviceWorker" in navigator && location.protocol.startsWith("http")) {
      navigator.serviceWorker.register("./service-worker.js").catch(err => console.warn("Service Worker:", err));
    }

    if (state.mode === "demo") {
      initDemo();
    } else {
      await initOnline();
    }
  }

  boot();
})();
