// 折扣碼對應的折扣百分比
export const COUPONS = { SAVE10: 10, HALF: 50 };

/**
 * 依折扣碼的百分比打折，回傳折扣後的金額。
 * 折扣碼不在 COUPONS 裡時 throw new Error('INVALID_COUPON')。
 * @param {number} total
 * @param {string} code
 * @returns {number}
 */
// TODO: export function applyCoupon(total, code)
