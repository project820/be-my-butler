#!/usr/bin/env bash
# =============================================================================
# BMB Mobile Landing Page Tests
# Tests: HTML validation, CSS validation, JS validation, cross-locale
#        consistency, architecture SVG invariants, drawer links
# =============================================================================

set -euo pipefail

DOCS_DIR="$(cd "$(dirname "$0")/../docs" && pwd)"
PASS=0
FAIL=0
ERRORS=()

# --- Helpers ---
pass() { ((PASS++)); echo "  PASS: $1"; }
fail() { ((FAIL++)); ERRORS+=("$1"); echo "  FAIL: $1"; }
assert_contains() {
  local file="$1" pattern="$2" msg="$3"
  if grep -q "$pattern" "$file" 2>/dev/null; then pass "$msg"; else fail "$msg"; fi
}
assert_not_contains() {
  local file="$1" pattern="$2" msg="$3"
  if grep -q "$pattern" "$file" 2>/dev/null; then fail "$msg"; else pass "$msg"; fi
}
# shellcheck disable=SC2317,SC2329
assert_count() {
  local file="$1" pattern="$2" expected="$3" msg="$4"
  local actual
  actual=$(grep -c "$pattern" "$file" 2>/dev/null || echo 0)
  if [[ "$actual" -eq "$expected" ]]; then pass "$msg (count=$actual)"; else fail "$msg (expected=$expected, got=$actual)"; fi
}

# =============================================================================
echo ""
echo "=== 1. HTML VALIDATION ==="
echo ""

LOCALES=("en:m.html" "ko:m.ko.html" "ja:m.ja.html" "zh-Hant:m.zh-TW.html")

for entry in "${LOCALES[@]}"; do
  lang="${entry%%:*}"
  file="${entry##*:}"
  filepath="$DOCS_DIR/$file"
  echo "--- $file (lang=$lang) ---"

  # File exists
  if [[ -f "$filepath" ]]; then pass "$file exists"; else fail "$file missing"; continue; fi

  # DOCTYPE
  assert_contains "$filepath" '<!DOCTYPE html>' "$file has DOCTYPE"

  # lang attribute
  assert_contains "$filepath" "<html lang=\"$lang\">" "$file has correct lang=$lang"

  # charset
  assert_contains "$filepath" '<meta charset="UTF-8">' "$file has charset UTF-8"

  # viewport
  assert_contains "$filepath" 'width=device-width, initial-scale=1.0' "$file has viewport meta"

  # canonical
  assert_contains "$filepath" "rel=\"canonical\" href=\".*${file}\"" "$file has self-canonical"

  # hreflang alternates (5: en, ko, ja, zh-Hant, x-default)
  alt_count=$(grep -c 'rel="alternate" hreflang=' "$filepath" 2>/dev/null || echo 0)
  if [[ "$alt_count" -eq 5 ]]; then pass "$file has 5 hreflang alternates"; else fail "$file hreflang count (expected=5, got=$alt_count)"; fi

  # OG meta tags
  assert_contains "$filepath" 'property="og:title"' "$file has og:title"
  assert_contains "$filepath" 'property="og:description"' "$file has og:description"
  assert_contains "$filepath" 'property="og:type"' "$file has og:type"

  # body class
  assert_contains "$filepath" 'class="mobile-landing"' "$file body has mobile-landing class"

  # data-page-family
  assert_contains "$filepath" 'data-page-family="mobile"' "$file has data-page-family=mobile"

  # Font references
  assert_contains "$filepath" 'IBM+Plex+Sans' "$file loads IBM Plex Sans"
  assert_contains "$filepath" 'JetBrains+Mono' "$file loads JetBrains Mono"

  # shared CSS and JS
  assert_contains "$filepath" 'href="bmb-shared.css"' "$file links bmb-shared.css"
  assert_contains "$filepath" 'src="bmb-shared.js"' "$file includes bmb-shared.js"

  # No Perplexity branding
  assert_not_contains "$filepath" 'Perplexity' "$file has no Perplexity branding"
  assert_not_contains "$filepath" 'PERPLEXITY' "$file has no PERPLEXITY branding"
done

# =============================================================================
echo ""
echo "=== 2. CSS VALIDATION ==="
echo ""

CSS_FILE="$DOCS_DIR/bmb-shared.css"

# .mobile-landing scoped styles exist
assert_contains "$CSS_FILE" '\.mobile-landing' "CSS has .mobile-landing scoped styles"

# scroll-snap-type: y proximity
assert_contains "$CSS_FILE" 'scroll-snap-type: y proximity' "CSS has scroll-snap-type: y proximity"

# scroll-snap-align on cards
assert_contains "$CSS_FILE" 'scroll-snap-align: start' "CSS has scroll-snap-align: start on cards"

# prefers-reduced-motion for mobile-landing
reduced_motion_mobile=$(grep -A5 'prefers-reduced-motion: reduce' "$CSS_FILE" | grep -c 'mobile-landing' || echo 0)
if [[ "$reduced_motion_mobile" -gt 0 ]]; then
  pass "CSS has prefers-reduced-motion for .mobile-landing"
else
  fail "CSS missing prefers-reduced-motion for .mobile-landing"
fi

# Card visibility transition
assert_contains "$CSS_FILE" 'ml-visible' "CSS has ml-visible class for card reveal"

# ml-card base styles
assert_contains "$CSS_FILE" '\.mobile-landing \.ml-card' "CSS has .mobile-landing .ml-card styles"

# Max-width constraint
max_width_found=$(grep -c 'max-width.*540\|max-width.*560\|max-width.*600' "$CSS_FILE" || echo 0)
if [[ "$max_width_found" -gt 0 ]]; then
  pass "CSS has max-width constraint for mobile cards"
else
  # Check ml-track or ml-card for max-width
  track_maxw=$(grep -A5 '\.ml-track\|\.ml-card' "$CSS_FILE" | grep -c 'max-width' || echo 0)
  if [[ "$track_maxw" -gt 0 ]]; then
    pass "CSS has max-width on ml-track/ml-card"
  else
    fail "CSS missing max-width constraint for mobile layout"
  fi
fi

# Card animation disabled for reduced motion
assert_contains "$CSS_FILE" 'prefers-reduced-motion: reduce' "CSS has prefers-reduced-motion: reduce rule"

# SVG animation disabled check in reduced motion block
svg_anim_disabled=$(awk '/prefers-reduced-motion: reduce/,/\}/' "$CSS_FILE" | grep -c 'ml-arch-svg\|animation' || echo 0)
if [[ "$svg_anim_disabled" -gt 0 ]]; then
  pass "CSS disables SVG animations in reduced-motion"
else
  fail "CSS may not disable SVG animations in reduced-motion"
fi

# =============================================================================
echo ""
echo "=== 3. JS VALIDATION ==="
echo ""

JS_FILE="$DOCS_DIR/bmb-shared.js"

# Mobile landing IntersectionObserver section
assert_contains "$JS_FILE" "mobile-landing" "JS checks for mobile-landing class"
assert_contains "$JS_FILE" "IntersectionObserver" "JS uses IntersectionObserver"

# Card reveal observer
assert_contains "$JS_FILE" "ml-visible" "JS adds ml-visible class on intersection"
assert_contains "$JS_FILE" "revealObserver" "JS has revealObserver for card reveal"

# Counter update observer
assert_contains "$JS_FILE" "counterObserver" "JS has counterObserver for counter update"
assert_contains "$JS_FILE" "ml-counter-current" "JS references ml-counter-current element"
assert_contains "$JS_FILE" "data-card" "JS reads data-card attribute for counter"

# Page family gating for language routing
assert_contains "$JS_FILE" "data-page-family" "JS reads data-page-family attribute"
assert_contains "$JS_FILE" "pageFamily" "JS has pageFamily variable"

# Language routing parameterized for m.* family
assert_contains "$JS_FILE" "prefix.*=.*'m'" "JS parameterizes prefix for mobile page family"

# langMap uses prefix variable
lang_map_mobile=$(grep -c "prefix.*+.*'.ko.html\|prefix.*+.*'.ja.html\|prefix.*+.*'.zh-TW.html" "$JS_FILE" || echo 0)
if [[ "$lang_map_mobile" -gt 0 ]]; then
  pass "JS langMap uses prefix for m.* family routing"
else
  # Check more broadly
  prefix_concat=$(grep -c "prefix + " "$JS_FILE" || echo 0)
  if [[ "$prefix_concat" -gt 0 ]]; then
    pass "JS langMap uses prefix concatenation"
  else
    fail "JS langMap may not be parameterized for m.* family"
  fi
fi

# Fallback for no IntersectionObserver
assert_contains "$JS_FILE" "ml-card.*ml-visible\|Fallback.*show all" "JS has fallback when IntersectionObserver unavailable"

# Threshold values
assert_contains "$JS_FILE" "threshold: 0.15" "JS revealObserver threshold is 0.15"
assert_contains "$JS_FILE" "threshold: 0.5" "JS counterObserver threshold is 0.5"

# =============================================================================
echo ""
echo "=== 4. CROSS-LOCALE CONSISTENCY ==="
echo ""

# All 4 pages must have exactly 7 cards with data-card="1" through data-card="7"
for entry in "${LOCALES[@]}"; do
  lang="${entry%%:*}"
  file="${entry##*:}"
  filepath="$DOCS_DIR/$file"

  echo "--- $file ---"

  # Count ml-card sections (only <section> tags with ml-card class, not sub-elements)
  card_count=$(grep -c '<section class="ml-card' "$filepath" || echo 0)
  if [[ "$card_count" -eq 7 ]]; then pass "$file has exactly 7 cards"; else fail "$file card count (expected=7, got=$card_count)"; fi

  # Verify data-card 1-7
  for n in 1 2 3 4 5 6 7; do
    assert_contains "$filepath" "data-card=\"$n\"" "$file has data-card=$n"
  done

  # Verify card type classes present
  assert_contains "$filepath" 'ml-cover' "$file has cover card"
  assert_contains "$filepath" 'ml-problem' "$file has problem card"
  assert_contains "$filepath" 'ml-pipeline' "$file has pipeline card"
  assert_contains "$filepath" 'ml-arch' "$file has architecture card"
  assert_contains "$filepath" 'ml-killer' "$file has killer feature card"
  assert_contains "$filepath" 'ml-dual' "$file has dual/for-everyone card"
  assert_contains "$filepath" 'ml-cta' "$file has CTA card"

  # 4 problem items
  problem_items=$(grep -c 'ml-problem-item' "$filepath" || echo 0)
  # Each item has opening and closing, so divide by 2... actually each <div class="ml-problem-item"> is one
  problem_divs=$(grep -c 'class="ml-problem-item"' "$filepath" || echo 0)
  if [[ "$problem_divs" -eq 4 ]]; then pass "$file has 4 problem items"; else fail "$file problem items (expected=4, got=$problem_divs)"; fi

  # Pipeline has 4 phases (PLAN, BUILD, VERIFY, REFINE)
  for phase in PLAN BUILD VERIFY REFINE; do
    assert_contains "$filepath" "$phase" "$file pipeline has $phase phase"
  done

  # Language bar present with 4 links
  lang_links=$(grep 'ml-lang-bar' -A10 "$filepath" | grep -c 'href="m\.' || echo 0)
  if [[ "$lang_links" -eq 4 ]]; then pass "$file has 4 language bar links"; else fail "$file lang bar links (expected=4, got=$lang_links)"; fi

  # Active language link matches current page
  active_link=$(grep 'ml-lang-bar' -A10 "$filepath" | grep 'class="active"' | grep -o 'href="[^"]*"' || echo "none")
  expected_href="href=\"$file\""
  if [[ "$active_link" == "$expected_href" ]]; then
    pass "$file active lang link points to self"
  else
    fail "$file active lang link mismatch (expected=$expected_href, got=$active_link)"
  fi

  # Footer link matches locale
  case "$lang" in
    en) expected_footer="index.html" ;;
    ko) expected_footer="index.ko.html" ;;
    ja) expected_footer="index.ja.html" ;;
    zh-Hant) expected_footer="index.zh-TW.html" ;;
  esac
  assert_contains "$filepath" "href=\"$expected_footer\"" "$file footer links to $expected_footer"

  # CTA stats present (9, 11.5, infinity)
  assert_contains "$filepath" '>9<' "$file CTA has 9 agents stat"
  assert_contains "$filepath" '>11.5<' "$file CTA has 11.5 steps stat"
  assert_contains "$filepath" 'infin' "$file CTA has infinity learning cycles"

  # GitHub link present
  assert_contains "$filepath" 'github.com/project820/be-my-butler' "$file has GitHub link"

  # MIT License mentioned
  assert_contains "$filepath" 'MIT License' "$file mentions MIT License"
done

# =============================================================================
echo ""
echo "=== 5. ARCHITECTURE SVG INVARIANTS ==="
echo ""

# 3 invariants: handoff flow, blind separation, worktree isolation
for entry in "${LOCALES[@]}"; do
  lang="${entry%%:*}"
  file="${entry##*:}"
  filepath="$DOCS_DIR/$file"

  echo "--- $file SVG ---"

  # Invariant 1: Handoff flow (Lead -> agents -> verify -> analyst)
  assert_contains "$filepath" '>Lead<' "$file SVG has Lead node"
  assert_contains "$filepath" '>Consultant<' "$file SVG has Consultant node"
  assert_contains "$filepath" '>Arch<' "$file SVG has Arch node"
  assert_contains "$filepath" '>Executor<' "$file SVG has Executor node"
  assert_contains "$filepath" '>Frontend<' "$file SVG has Frontend node"
  assert_contains "$filepath" '>Tester<' "$file SVG has Tester node"
  assert_contains "$filepath" 'Cross-Model Verify' "$file SVG has Cross-Model Verify"
  assert_contains "$filepath" 'Analyst' "$file SVG has Analyst node"

  # Invariant 2: Blind separation (BLIND WALL)
  assert_contains "$filepath" 'BLIND WALL' "$file SVG has BLIND WALL text"
  # Dashed line representation
  assert_contains "$filepath" 'stroke-dasharray="6 4"' "$file SVG has dashed blind wall line"

  # Invariant 3: Worktree isolation
  assert_contains "$filepath" 'WORKTREE ISOLATION' "$file SVG has WORKTREE ISOLATION text"
  assert_contains "$filepath" 'FILE-BASED HANDOFFS' "$file SVG has FILE-BASED HANDOFFS text"

  # SVG has animateMotion elements (animated handoff flow)
  anim_count=$(grep -c 'animateMotion' "$filepath" || echo 0)
  if [[ "$anim_count" -ge 3 ]]; then
    pass "$file SVG has $anim_count animateMotion elements"
  else
    fail "$file SVG animateMotion count (expected>=3, got=$anim_count)"
  fi

  # SVG has role="img" and aria-label
  assert_contains "$filepath" 'role="img"' "$file SVG has role=img"
  assert_contains "$filepath" 'aria-label=' "$file SVG has aria-label"

  # Arrow marker defs
  assert_contains "$filepath" 'mlArrowBlue' "$file SVG has blue arrow marker"
  assert_contains "$filepath" 'mlArrowPink' "$file SVG has pink arrow marker"
  assert_contains "$filepath" 'mlArrowAmber' "$file SVG has amber arrow marker"
done

# =============================================================================
echo ""
echo "=== 6. DRAWER LINKS IN INDEX FILES ==="
echo ""

INDEX_FILES=("en:index.html:m.html" "ko:index.ko.html:m.ko.html" "ja:index.ja.html:m.ja.html" "zh-TW:index.zh-TW.html:m.zh-TW.html")

for entry in "${INDEX_FILES[@]}"; do
  IFS=: read -r lang idx_file mobile_file <<< "$entry"
  filepath="$DOCS_DIR/$idx_file"

  if [[ -f "$filepath" ]]; then
    # Check for mobile summary link in drawer
    if grep -q "href=\"$mobile_file\"" "$filepath"; then
      pass "$idx_file has drawer link to $mobile_file"
    else
      fail "$idx_file missing drawer link to $mobile_file"
    fi
  else
    fail "$idx_file file not found"
  fi
done

# =============================================================================
echo ""
echo "========================================"
echo "  RESULTS"
echo "========================================"
echo "  PASS: $PASS"
echo "  FAIL: $FAIL"
echo "  TOTAL: $((PASS + FAIL))"
echo ""

if [[ ${#ERRORS[@]} -gt 0 ]]; then
  echo "  FAILURES:"
  for e in "${ERRORS[@]}"; do
    echo "    - $e"
  done
fi

echo ""
if [[ "$FAIL" -eq 0 ]]; then
  echo "  OVERALL: PASS"
  exit 0
else
  echo "  OVERALL: FAIL"
  exit 1
fi
