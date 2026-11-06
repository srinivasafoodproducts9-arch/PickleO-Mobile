---
name: PickleO Design System
colors:
  surface: '#fff8f6'
  surface-dim: '#fbd1c4'
  surface-bright: '#fff8f6'
  surface-container-lowest: '#ffffff'
  surface-container-low: '#fff1ed'
  surface-container: '#ffe9e3'
  surface-container-high: '#ffe2da'
  surface-container-highest: '#ffdbd0'
  on-surface: '#2c160e'
  on-surface-variant: '#404942'
  inverse-surface: '#442a22'
  inverse-on-surface: '#ffede8'
  outline: '#707971'
  outline-variant: '#c0c9c0'
  surface-tint: '#2d6a48'
  primary: '#003820'
  on-primary: '#ffffff'
  primary-container: '#0f5132'
  on-primary-container: '#84c39b'
  inverse-primary: '#95d4ac'
  secondary: '#964900'
  on-secondary: '#ffffff'
  secondary-container: '#fc820c'
  on-secondary-container: '#5e2c00'
  tertiary: '#755b00'
  on-tertiary: '#ffffff'
  tertiary-container: '#d2a500'
  on-tertiary-container: '#4f3d00'
  error: '#ba1a1a'
  on-error: '#ffffff'
  error-container: '#ffdad6'
  on-error-container: '#93000a'
  primary-fixed: '#b0f1c7'
  primary-fixed-dim: '#95d4ac'
  on-primary-fixed: '#002111'
  on-primary-fixed-variant: '#0f5132'
  secondary-fixed: '#ffdcc6'
  secondary-fixed-dim: '#ffb786'
  on-secondary-fixed: '#311300'
  on-secondary-fixed-variant: '#723600'
  tertiary-fixed: '#ffdf90'
  tertiary-fixed-dim: '#f0c12c'
  on-tertiary-fixed: '#241a00'
  on-tertiary-fixed-variant: '#584400'
  background: '#fff8f6'
  on-background: '#2c160e'
  surface-variant: '#ffdbd0'
typography:
  display-lg:
    fontFamily: Poppins
    fontSize: 32px
    fontWeight: '700'
    lineHeight: 40px
  display-lg-mobile:
    fontFamily: Poppins
    fontSize: 26px
    fontWeight: '700'
    lineHeight: 34px
  headline-story:
    fontFamily: Lora
    fontSize: 24px
    fontWeight: '600'
    lineHeight: 32px
  headline-story-mobile:
    fontFamily: Lora
    fontSize: 20px
    fontWeight: '600'
    lineHeight: 28px
  title-lg:
    fontFamily: Poppins
    fontSize: 18px
    fontWeight: '600'
    lineHeight: 24px
  title-md:
    fontFamily: Poppins
    fontSize: 16px
    fontWeight: '600'
    lineHeight: 22px
  story-body:
    fontFamily: Lora
    fontSize: 15px
    fontWeight: '400'
    lineHeight: 24px
  body-regular:
    fontFamily: Poppins
    fontSize: 14px
    fontWeight: '400'
    lineHeight: 20px
  body-medium:
    fontFamily: Poppins
    fontSize: 14px
    fontWeight: '500'
    lineHeight: 20px
  label-bold:
    fontFamily: Poppins
    fontSize: 12px
    fontWeight: '700'
    lineHeight: 16px
  label-sm:
    fontFamily: Poppins
    fontSize: 11px
    fontWeight: '500'
    lineHeight: 14px
  price-lg:
    fontFamily: Poppins
    fontSize: 20px
    fontWeight: '700'
    lineHeight: 26px
rounded:
  sm: 0.25rem
  DEFAULT: 0.5rem
  md: 0.75rem
  lg: 1rem
  xl: 1.5rem
  full: 9999px
spacing:
  gutter: 1rem
  margin: 1rem
  space-xs: 0.25rem
  space-sm: 0.5rem
  space-md: 1rem
  space-lg: 1.5rem
  space-xl: 2rem
---

## Brand & Style

### Brand Personality & Philosophy
This design system embodies the warmth of homemade culinary heritage, regional artisanal authenticity, and modern mobile commerce convenience. The brand voice balances rustic culinary intimacy—reminiscent of grandma's clay pickle jars (*martaban*) and fragrant spice pantries—with high-trust, hygienic food delivery reliability. 

### Visual Movement & Aesthetic Tone
The visual style is **Warm Modern Artisanal**:
- **Appetizing & Grounded:** Clean cream backgrounds replace harsh digital whites, invoking sun-warmed farmsteads, raw stone kitchens, and natural muslin cloth.
- **Vibrant Flavor Accents:** Direct color borrowing from Indian spice cabinets (mustard yellow, kashmiri chilli red, tangy pickle oil orange, and lush curry leaf green).
- **Tactile Softness:** Subtly rounded geometry (16px cards, 12px buttons) paired with fine linework icons to create approachable, thumb-friendly touch surfaces without visual clutter.
- **Editorial Warmth:** Editorial serif moments for regional origin narratives alongside clean geometric sans typography for price, weight, ingredients, and checkout states.

## Colors

### Palette Philosophy
The palette captures the sensory palette of Indian pickling and regional snacking:

- **Primary (`#0F5132` — Leaf Green):** Symbolizes purity, traditional cold-pressed ingredients, freshness, and serves as the core brand foundation. Acts as the visual anchor for primary navigation, high-conviction verification badges, and the Indian vegetarian compliance marker.
- **Secondary (`#F57C00` — Pickle Orange):** Elicits appetite, warmth, oil-infused spices, and culinary energy. Designated for primary call-to-actions (Add to Cart, Buy Now, checkout flows), urgent promotional cues, and active indicators.
- **Tertiary (`#F4C430` — Spice Yellow):** Evokes roasted turmeric, mustard seeds, and celebration. Utilized for review star ratings, savings callouts, artisanal batch badges, and spotlight banners.
- **Chilli Red (`#C0392B`):** Dedicated to culinary spice-level heat meters, stock urgency warnings, heart favorite toggles, and critical validation alerts.
- **Warm Cream Canvas (`#FFF6E8`):** The foundational surface layer. Softens eye fatigue, creates an appetizing warm backdrop, and harmonizes spice tones better than sterile `#FFFFFF`.
- **Earth Brown (`#5D4037`):** The primary neutral for body text, headings, and outlines. Imparts an organic, earthy feel, avoiding the harshness of pure black (`#000000`) while maintaining WCAG AAA contrast against cream surfaces.

### Semantic & Surface Tokens
- `surface-canvas`: `#FFF6E8`
- `surface-card`: `#FFFFFF`
- `surface-card-subtle`: `#FFFDF9`
- `text-primary`: `#2D1E18` (Deep Earth)
- `text-secondary`: `#5D4037` (Muted Earth)
- `text-tertiary`: `#8D6E63` (Terracotta Dust)
- `border-subtle`: `#EFE4D2`
- `border-strong`: `#D7C7B2`
- `status-veg`: `#0F5132`

## Typography

### Structural Pairing
The typography is structured into two distinct roles:
1. **Poppins (Geometric Sans-Serif):** Provides high legibility at micro sizes on mobile screens. Utilized for app headers, component actions, product titles, numerical prices, nutritional facts, and checkout input labels.
2. **Lora (Humanist Contemporary Serif):** Channels traditional print culinary journals and storytelling. Deployed for maker backstories, regional heritage introductions (e.g., "From the mango orchards of Guntur"), recipe pairings, and testimonial quotes.

### Indian E-Commerce Nuances
- Price figures must always use `Poppins Bold` with the Indian Rupee symbol (`₹`) formatted seamlessly adjacent to the numerical value without an extra space (e.g., `₹249`).
- Grammage and shelf-life metrics use `label-sm` in `text-secondary` to remain scannable in two-column grid mobile listings.

## Layout & Spacing

### Mobile-First Spacing Rhythm
The design system operates on an 8-point spatial system with a 4-point micro-scale:
- **Canvas Margins:** Fixed `16px` (`margin`) outer horizontal safe padding on mobile devices, expanding to `24px` on tablet viewports.
- **Grid Structure:** 
  - Mobile (360px - 480px): 4-column fluid layout with `16px` gutters. Product cards display as a 2-column grid (`calc(50% - 8px)` width) or single-item horizontal carousels.
  - Tablet (600px - 840px): 8-column layout with `20px` gutters and `32px` margins.
- **Touch Targets:** Minimum interactive area of `48px × 48px` on all buttons, quantity steppers, and filter chips.
- **Section Rhythm:** Grouped content cards use `space-md` (16px) separation; narrative blocks and promotional banners use `space-xl` (32px) breathing room.

## Elevation & Depth

### Ambient Warmth Strategy
Rather than cold, mechanical drop shadows, depth is achieved using warm-tinted ambient glows that mimic natural sunlight filtering into a traditional Indian kitchen:

- **Level 0 (Flat / Recessed):** Plain `#FFF6E8` canvas or `#F5ECDC` inset containers for input fields and quantity counters.
- **Level 1 (Card Rest):** Used for standard product cards, category circular tiles, and review modules:
  `box-shadow: 0 4px 14px -2px rgba(93, 64, 55, 0.06), 0 2px 6px -1px rgba(93, 64, 55, 0.04);`
- **Level 2 (Hover / Active Card):** Elevated state when tapping or dragging:
  `box-shadow: 0 8px 24px -4px rgba(93, 64, 55, 0.12), 0 4px 10px -2px rgba(93, 64, 55, 0.06);`
- **Level 3 (Sticky Bottom Bar / Modal Bottom Sheet):** Used for persistent Cart Bar, UPI checkout sheets, and filter drawers:
  `box-shadow: 0 -4px 24px 0 rgba(93, 64, 55, 0.08);`
- **Border Integration:** All elevated cards include an ultra-subtle perimeter hairline border (`1px solid rgba(93, 64, 55, 0.08)`) to preserve card boundaries on screens with saturated display panels.

## Shapes

### Rounded Hierarchy
The shape language emphasizes approachability and tactile comfort:
- **Base Components (Inputs, Primary Buttons, Action Sheets):** `12px` border radius (`rounded`). Creates a sturdy, modern mobile button contour.
- **Containers & Product Cards:** `16px` border radius (`rounded-lg`). Softens the edges of heavy photography grids.
- **Category Icons & Hero Teasers:** `24px` to full circular (`rounded-full`) for circular subcategory quick-links (e.g., Mango, Lemon, Garlic, Snacks).
- **Pills & Chips:** Fully pill-shaped (`9999px`) for category filter chips, discount tags, spice level meters, and verification badges.

## Components

### 1. Buttons
- **Primary Action (Add to Cart / Buy Now):** Background `#F57C00` (Pickle Orange), text `#FFFFFF`, height `48px`, border-radius `12px`, typography `Poppins SemiBold 15px`. Active press scales down slightly (`scale(0.98)`).
- **Secondary / Narrative (Explore Heritage / View All):** Outlined with `#0F5132` (Leaf Green, 1.5px border), transparent or `#FFFDF9` background, text `#0F5132`.
- **Inline Card Stepper (+ / - Quantity):** Background `#FFF6E8` bordered with `#0F5132`. Displays numerical count centered with green math icons (`+` / `−`), height `36px`, pill-shaped or 8px rounded corners.

### 2. Product Cards
- **Structure:** Top container holds the imagery with a warm neutral background (`#FAF2E6`), top-left vegetarian compliance indicator, and top-right wishlist heart icon.
- **Content:** Product Title (`Poppins 14px SemiBold`), weight variation dropdown (e.g., `250g`, `500g`), star rating chip (`#F4C430` badge with Earth Brown text), price formatted in bold (`₹249`), and inline Add button.
- **Visuals:** Jar photography must showcase clean cutouts or styled wooden spoon staging.

### 3. Food Badges & Indicators
- **Vegetarian Symbol (Indian Standard):** Square border with a solid centered circle in `#0F5132` (Leaf Green). Dimensions `14px × 14px`.
- **Spice Meter Tag:** Pill container with 1 to 3 red chilli icons indicating pungency (`Mild`, `Medium Spicy`, `Traditional Andhra Hot`).
- **Authenticity Tag:** Cream tag with `#0F5132` text and tiny leaf icon: *"Grandma's Recipe"*, *"Sun-Dried"*, or *"Cold-Pressed Oil"*.

### 4. Form Fields & Verification
- **Input Fields (OTP, Phone, Delivery Address):** `48px` height, background `#FFFFFF`, border `1.5px solid #EFE4D2`, radius `12px`. Focus state shifts border to `#0F5132` with a subtle green tint shadow.
- **Mobile Number Prefix:** Pre-filled `+91` flag icon in a fixed earth-toned container segment.
- **OTP Verification Blocks:** 4 to 6 individual square rounded boxes (`48px × 48px`), auto-advancing on keypad entry.

### 5. Filter Chips & Horizontal Lists
- **State Inactive:** `#FFFFFF` background, `1px solid #EFE4D2`, text `#5D4037`.
- **State Active:** `#0F5132` background, text `#FFFFFF`, `none` border.
- **Dimensions:** Pill radius `9999px`, padding `8px 16px`, typography `Poppins 13px Medium`.

### 6. Checkout & Payment Modules
- **UPI Quick Pay Tray:** Distinct elevated card holding Google Pay, PhonePe, and Paytm logos with one-tap payment triggers.
- **Savings Banner:** `#FFF4D9` background with `#F57C00` dashed border, highlighting applied coupon codes and festival offers.