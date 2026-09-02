/* 의존성 없는 SVG 도넛 차트 — 둥근 세그먼트 + 탭 인터랙션 */
import { won, shortWon, pct } from "./calc.js";

const R = 100, HOLE = 76, CX = 110, CY = 110;
const RING_R = (R + HOLE) / 2;     // 88 — 세그먼트 중심 반지름
const RING_SW = R - HOLE;          // 24 — 세그먼트 두께 (얇은 링일수록 둥근 끝의 비중이 줄어 작은 항목도 잘 보인다)
const CIRC = 2 * Math.PI * RING_R; // 원둘레
const GAP_PX = 4;                  // 세그먼트 사이 여백
const MIN_DASH = 2.5;              // 값이 아주 작아도 보이는 최소 길이(점)
const HOVER_GROW = 6;              // 선택 시 바깥으로 자라는 양
const STAGGER_BASE = 90;           // 등장 애니메이션 딜레이(ms) — CSS .pie__seg 의 지속시간과 짝을 이룬다
const STAGGER_STEP = 70;

/**
 * @param {Array<{key,value,color}>} slices
 * @param {{centerLabel?:string}} opts
 */
export function donut(slices, opts = {}) {
  const data = slices.filter(s => s.value > 0);
  const total = data.reduce((s, d) => s + d.value, 0);
  if (!total) {
    return `<p class="pie__empty">기간 안에 표시할 금액이 없습니다</p>`;
  }

  const single = data.length === 1;
  let acc = 0;
  const segs = data.map((d, i) => {
    const rawLen = (d.value / total) * CIRC;
    const trueStart = acc;
    acc += rawLen;
    let dashLen, segStart;
    if (single) {
      dashLen = CIRC;
      segStart = 0;
    } else {
      const shrink = RING_SW + GAP_PX;
      dashLen = Math.max(rawLen - shrink, MIN_DASH);
      const mid = trueStart + rawLen / 2;
      segStart = mid - dashLen / 2;
    }
    const offset = -segStart;
    // transition-property 순서(stroke-dasharray, r, stroke-width, opacity, filter)에 맞춰
    // 등장 딜레이는 첫 항목에만 주고 나머지는 0으로 — 안 그러면 호버 반응까지 늦어진다
    const delay = STAGGER_BASE + i * STAGGER_STEP;
    return `<circle class="pie__seg" data-index="${i}" data-final-dash="${dashLen}"
      data-key="${esc(d.key)}" data-value="${d.value}"
      cx="${CX}" cy="${CY}" r="${RING_R}" fill="none" stroke="${d.color}"
      stroke-width="${RING_SW}" stroke-linecap="round"
      style="stroke-dasharray:0 ${CIRC};stroke-dashoffset:${offset};transition-delay:${delay}ms,0s,0s,0s,0s;--seg-glow:${d.color};--r0:${RING_R}px;--sw0:${RING_SW}px;--grow:${HOVER_GROW}px"
      ><title>${esc(d.key)} · ${won(d.value)}원 (${pct(d.value, total)})</title></circle>`;
  }).join("");

  const label = opts.centerLabel || "합계";
  return `<svg class="pie__svg" viewBox="-14 -14 248 248" role="img" aria-label="${esc(label)} ${won(total)}원" data-total="${total}" data-label="${esc(label)}">
    <g class="pie__ring" transform="rotate(-90 ${CX} ${CY})">${segs}</g>
    <g class="pie__hole" data-hole>
      <text class="pie__hole-k" data-hole-k x="${CX}" y="${CY - 8}" text-anchor="middle">${esc(label)}</text>
      <text class="pie__hole-v" data-hole-v x="${CX}" y="${CY + 16}" text-anchor="middle">${shortWon(total)}</text>
    </g>
  </svg>`;
}

export function legend(slices) {
  const data = slices.filter(s => s.value > 0);
  const total = data.reduce((s, d) => s + d.value, 0);
  if (!total) return "";
  return data.map((d, i) => `
    <button class="legend__r" type="button" data-index="${i}">
      <span class="legend__d" style="background:${d.color}"></span>
      <span class="legend__k">${esc(d.key)}</span>
      <span class="legend__p">${pct(d.value, total)}</span>
      <span class="legend__v">${won(d.value)}</span>
    </button>`).join("");
}

/**
 * donut()/legend()가 innerHTML로 심어진 뒤 호출 — 등장 애니메이션을 재생하고
 * 세그먼트↔범례 탭 연동, 가운데 합계/항목 전환을 붙인다.
 * @param {HTMLElement} pieEl  .pie 컨테이너 (donut() 결과가 들어있음)
 * @param {HTMLElement=} legendEl .legend 컨테이너 (legend() 결과가 들어있음, 선택)
 */
export function mountPie(pieEl, legendEl) {
  const svg = pieEl?.querySelector(".pie__svg");
  if (!svg) return;

  const segs = [...svg.querySelectorAll(".pie__seg")];
  const holeK = svg.querySelector("[data-hole-k]");
  const holeV = svg.querySelector("[data-hole-v]");
  const total = Number(svg.dataset.total || 0);
  const defaultLabel = svg.dataset.label || "합계";
  const rows = legendEl ? [...legendEl.querySelectorAll(".legend__r")] : [];
  if (legendEl) legendEl.classList.add("legend--linked");

  // 등장 애니메이션: 다음 프레임에 최종 길이로 전환 (지속시간/이징은 CSS .pie__seg 에서 정의)
  requestAnimationFrame(() => requestAnimationFrame(() => {
    segs.forEach(c => {
      const dash = Number(c.dataset.finalDash);
      c.style.strokeDasharray = `${dash} ${CIRC - dash}`;
    });
  }));

  let activeIndex = null;
  let valueRaf = null;

  function animateValue(el, from, to, ms) {
    if (valueRaf) cancelAnimationFrame(valueRaf);
    const start = performance.now();
    const step = now => {
      const t = Math.min(1, (now - start) / ms);
      const eased = 1 - (1 - t) ** 3;
      el.textContent = shortWon(from + (to - from) * eased);
      valueRaf = t < 1 ? requestAnimationFrame(step) : null;
    };
    valueRaf = requestAnimationFrame(step);
  }

  function swapLabel(el, text) {
    el.style.transition = "opacity .12s ease";
    el.style.opacity = "0";
    setTimeout(() => { el.textContent = text; el.style.opacity = "1"; }, 120);
  }

  function setActive(index) {
    const prevValue = activeIndex === null ? total : Number(segs[activeIndex]?.dataset.value || 0);
    activeIndex = index;

    segs.forEach((c, i) => {
      c.classList.toggle("is-active", i === index);
      c.classList.toggle("is-dim", index !== null && i !== index);
    });
    rows.forEach((r, i) => {
      r.classList.toggle("is-active", i === index);
      r.classList.toggle("is-dim", index !== null && i !== index);
    });

    const target = index === null ? total : Number(segs[index]?.dataset.value || 0);
    const label = index === null ? defaultLabel : segs[index]?.dataset.key || defaultLabel;
    if (holeK) swapLabel(holeK, label);
    if (holeV) animateValue(holeV, prevValue, target, 300);
  }

  segs.forEach((c, i) => {
    c.addEventListener("click", () => setActive(activeIndex === i ? null : i));
  });
  rows.forEach((r, i) => {
    r.addEventListener("click", () => setActive(activeIndex === i ? null : i));
  });
  svg.addEventListener("click", e => {
    if (e.target === svg || e.target.closest("[data-hole]")) setActive(null);
  });
}

/** 거래처 카드의 작업 구성 막대 */
export function miniBar(parts) {
  const total = parts.reduce((s, p) => s + p.value, 0);
  if (!total) return "";
  return parts.filter(p => p.value > 0)
    .map(p => `<i style="width:${(p.value / total) * 100}%;background:${p.color}"></i>`).join("");
}

export const esc = s => String(s ?? "").replace(/[&<>"']/g, m => ({ "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;" }[m]));
