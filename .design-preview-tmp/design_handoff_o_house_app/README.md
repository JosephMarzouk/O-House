# Handoff: O House Mobile App Design

## Overview
O House is a property management mobile app for residential units. The design includes user onboarding, assignment workflows (task acceptance/rejection), signature capture, and checklist management with support for right-to-left (RTL) languages.

## About the Design Files
The files in this bundle are **design references created in HTML** — fully interactive prototypes showing intended look, interactions, and behavior. These are NOT production code to be shipped directly. Your task is to **recreate these HTML designs in your target codebase** (React Native, Flutter, native iOS/Android, or web framework) using its established patterns and libraries.

## Design System
This design uses the **Broadsheet** design system:
- **Typography**: Source Serif 4 (headings and body)
- **Colors**: 
  - Primary (Cyan): #0088b0
  - Secondary (Magenta): #d6006c
  - Text: #201e1d (deep ink)
  - Background: #f3f2f2 (paper white)
- **Spacing**: 1.25× density scale (var(--space-xs through var(--space-lg))
- **Radius**: 2px (var(--radius-sm))
- **Shadows**: var(--shadow-sm/md/lg)

## Fidelity
**High-fidelity (hifi)**: Pixel-perfect interactive mockups with final colors, typography, spacing, and all interactions working. The developer should recreate these designs pixel-for-pixel in the target platform.

## Screens

### 1. Onboarding Cover (1a)
- **Purpose**: App launch screen; introduces O House
- **Layout**: Full-screen vertical center; serif headline, subtitle, hero imagery placeholder
- **Components**: Large Source Serif 4 title, body copy, centered call-to-action button (cyan primary)
- **Interactions**: Button navigates to next screen
- **Copy**: Shown in design file (exact text to be preserved)

### 2. Property Selection (1b)
- **Purpose**: User selects which property/unit they manage
- **Layout**: Full-screen list; sticky header with property name
- **Components**: Property cards (address, unit, status badge), segmented selector for view mode
- **Interactions**: Tap card to select property; selection persists to Assignment Detail
- **State**: selectedProperty stored in app state

### 3. Assignment Detail (1c, 1d, 1e)
- **Purpose**: Core workflow—review task assignment, accept or reject, mark items complete
- **Layout**: Sticky header (property name, RTL toggle), scrollable content, sticky action buttons below
- **Components**:
  - Header: Property name + RTL language toggle button
  - Task info card: Assignment ID, due date, description
  - Checklist section: Checkbox items with labels, ticking state persisted
  - Interactive elements: Accept / Reject buttons
- **Interactions**:
  - Checkboxes toggle ✓ state in real-time
  - Accept button opens signature capture (1g)
  - Reject button shows confirmation modal
  - RTL toggle flips entire screen layout (text direction: rtl)
- **States**: checklist items (unchecked/checked), assignment (pending/accepted/rejected)

### 4. Signature Canvas (1g)
- **Purpose**: Capture user signature on assignment acceptance
- **Layout**: Full-screen canvas with header, footer buttons
- **Components**:
  - Signature pad (HTML5 canvas element)
  - "Clear" and "Confirm" buttons
  - Prompt text: "Sign to confirm acceptance"
- **Interactions**:
  - Draw on canvas with touch/mouse
  - Clear button resets canvas
  - Confirm button saves signature (mock) and returns to Assignment Detail in "accepted" state
- **Technical**: Use HTML5 Canvas API or existing signature library (SignaturePad.js recommended)

### 5. Rejection Flow
- **Purpose**: Confirm rejection with reason
- **Layout**: Modal dialog over Assignment Detail
- **Components**: Reason text area, Cancel / Confirm Rejection buttons
- **Interactions**: Confirm saves rejection, returns to Property Selection

### 6. Checklist Item Interaction
- **Purpose**: User can mark items complete as they work through assignment
- **Layout**: Inline checkbox + label per item
- **Components**: SVG checkbox (unchecked → checked with cyan checkmark), label text
- **Interactions**: Tap checkbox; state updates immediately and persists in component state
- **States**: unchecked (light gray background), checked (cyan fill + white checkmark)

### 7. RTL Assignment Detail (1e)
- **Purpose**: Same as 1c/1d but with right-to-left text direction and mirrored layout
- **Layout**: All flex/grid directions reversed; text aligned right; buttons and icons mirrored
- **Technical**: `direction: rtl` applied to root; ensure all margins/padding work in RTL context
- **Copy**: Same content as 1c, but rendered RTL

## Interactions & Behavior

### Navigation Flow
1. Onboarding Cover (1a) → Property Selection (1b)
2. Property Selection → Assignment Detail (1c/1d)
3. Assignment Detail → Signature Canvas (1g) [on Accept] or Rejection Confirmation [on Reject]
4. Signature Canvas → Assignment Detail (accepted state)
5. Rejection Confirmation → Property Selection

### Assignment Acceptance Flow
- User taps "Accept" button
- Signature Canvas opens (1g)
- User signs and taps "Confirm"
- Signature saved (mock in prototype; real backend call in production)
- Returns to Assignment Detail with status changed to "Accepted"
- Accept/Reject buttons hidden; "Done" button visible

### Assignment Rejection Flow
- User taps "Reject" button
- Modal appears asking for reason
- User enters reason and confirms
- Assignment marked as "Rejected"
- Returns to Property Selection

### Checklist Interaction
- User taps any checkbox in the checklist
- Checkbox state toggles immediately (optimistic update)
- State persists in component memory for the duration of the session
- (In production, would be saved to backend)

### RTL Toggle
- User taps RTL button in Assignment Detail header
- Entire screen flips to right-to-left layout
- All text, labels, and icons mirror
- Buttons reposition to accommodate RTL
- State persists for the session

## State Management

### Global App State
```
{
  currentScreen: 'onboarding' | 'property-selection' | 'assignment-detail' | 'signature-canvas' | 'rejection',
  selectedProperty: { id, address, unit, status },
  currentAssignment: { id, dueDate, description, items: [] },
  isRTL: boolean,
  userSignature: null | 'data:image/png;base64,...'
}
```

### Assignment State
```
{
  id: string,
  propertyId: string,
  dueDate: string (ISO 8601),
  description: string,
  items: [
    { id, label, completed: boolean },
    ...
  ],
  status: 'pending' | 'accepted' | 'rejected',
  rejectionReason: null | string,
  signatureData: null | canvas blob
}
```

### Component State
- Checklist items (checked/unchecked per item)
- Signature canvas (drawing buffer)
- Modal visibility (rejection confirmation)
- RTL toggle (persisted per session)

## Design Tokens

### Colors
- Cyan (Primary): #0088b0
- Magenta (Secondary): #d6006c
- Text: #201e1d
- Background: #f3f2f2
- Neutral tints: var(--color-neutral-100 through -900)
- Accent ramps: var(--color-accent-100 through -900), var(--color-accent-2-100 through -900)

### Typography
- **Font Family**: Source Serif 4
- **Heading (H1)**: 48px, 700 weight, line-height 1.25
- **Heading (H2)**: 32px, 700 weight, line-height 1.25
- **Body**: 16px, 400 weight, line-height 1.5
- **Label**: 14px, 400 weight, line-height 1.5
- **Caption**: 12px, 400 weight, line-height 1.5

### Spacing
- xs: 4px
- sm: 8px
- md: 16px
- lg: 24px
- xl: 32px
- 2xl: 48px

### Shadows
- sm: 0 2px 4px rgba(0,0,0,0.1)
- md: 0 4px 8px rgba(0,0,0,0.15)
- lg: 0 8px 16px rgba(0,0,0,0.2)

### Radius
- sm: 2px

## Assets
- **Icons**: Phosphor Icons (duotone weight)
- **Images**: Placeholder for hero imagery on onboarding and property cards (use image-slot.js or equivalent)
- **Fonts**: Source Serif 4 (load from Google Fonts or system; Broadsheet design system provides CSS variables)

## Files
- `O House.dc.html` — Main design component with all 7 screens (1a–1g)
- `O House Deck.dc.html` — Presentation deck with 11 slides (overview + detailed annotations per screen)
- `_ds/broadsheet-68ab1c78-0874-481d-b979-923b1a81f51a/` — Broadsheet design system bundle (colors, type, components)

## Implementation Notes

### For React / React Native
- Use component state (useState) for checklist, RTL toggle, and modal visibility
- Use a router (React Navigation for mobile, React Router for web) for screen transitions
- For signature capture, use react-signature-canvas or similar
- Use CSS-in-JS or native RN styles to apply direction: rtl for RTL screen

### For Flutter
- Use Provider or GetX for state management
- Use Navigator for screen transitions
- For signature, use signature package
- Use Directionality widget to handle RTL

### For Native iOS
- Use UIViewController hierarchy for screen navigation
- Core Graphics or a signature library for canvas
- Use UIView.semanticContentAttribute = .forceRightToLeft for RTL

### For Native Android
- Use Fragment-based navigation
- Canvas API for signature drawing
- android:layoutDirection="rtl" in XML for RTL screens

### For Web (Vanilla JS / Next.js)
- Manage app state with Context API or simple object
- Use HTML5 Canvas API for signature
- Use CSS direction: rtl for RTL layout
- Ensure all flex/grid gaps and margins work in RTL context
