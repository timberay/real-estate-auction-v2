// Shared constants for Stimulus controllers. Import from sibling controllers:
//   import { ANIMATION_DURATION_MS, KOR_EOK_TO_MAN } from "controllers/constants"
//
// Group conventions:
//   ANIMATION_*_MS  — UI animation/transition timings (milliseconds)
//   *_DURATION_MS   — feedback/notification durations (milliseconds)
//   BYTES_PER_*     — binary size units
//   KOR_*_TO_MAN    — Korean currency unit conversions (everything in 만원)

// UI animation
export const ANIMATION_DURATION_MS = 300
export const TOAST_DEFAULT_DURATION_MS = 5000
export const COPY_FEEDBACK_DURATION_MS = 2000

// Binary size
export const BYTES_PER_KB = 1024
export const BYTES_PER_MB = 1024 * 1024

// Korean currency: app stores 만원 (10,000 won) as the base unit.
//   1억 = 10,000만원 → multiply by KOR_EOK_TO_MAN to convert 억 → 만원
//   N천만원 = N × 1,000 만원 → multiply by KOR_CHEON_TO_MAN
export const KOR_EOK_TO_MAN = 10000
export const KOR_CHEON_TO_MAN = 1000
