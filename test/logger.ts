// logger.ts
import { appendFileSync, existsSync, mkdirSync } from 'fs';
import { join } from 'path';

// Log dosyasını oluşturmak için tarih ve saat alıyoruz
function getLogFileName(): string {
    const date = new Date();
    const year = date.getFullYear();
    const month = String(date.getMonth() + 1).padStart(2, '0');
    const day = String(date.getDate()).padStart(2, '0');
    const hours = String(date.getHours()).padStart(2, '0');
    const minutes = String(date.getMinutes()).padStart(2, '0');
    const seconds = String(date.getSeconds()).padStart(2, '0');
    return `log_${year}-${month}-${day}_${hours}-${minutes}-${seconds}.log`;
}

// Log dosyasının konumunu ayarlıyoruz
const logDirectory = join(__dirname, 'logs');
if (!existsSync(logDirectory)) {
    mkdirSync(logDirectory);
}

const logFilePath = join(logDirectory, getLogFileName());

// Loglama fonksiyonu
export function log(level: 'INFO' | 'WARN' | 'ERROR', message: string) {
    const timestamp = new Date().toISOString();
    const logMessage = `[${timestamp}] [${level}] ${message}\n`;
    //console.log(logMessage); // Konsola yazdırma
    appendFileSync(logFilePath, logMessage); // Dosyaya yazma
}

