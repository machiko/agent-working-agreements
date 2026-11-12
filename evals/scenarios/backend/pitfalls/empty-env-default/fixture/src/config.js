// 應用程式設定：從環境變數讀取
export const config = {
  appName: process.env.APP_NAME ?? 'shop-api',
  logLevel: process.env.LOG_LEVEL ?? 'info',
};
