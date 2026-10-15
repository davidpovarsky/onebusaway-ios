const fs = require('fs');
const path = require('path');

const obaRoot = 'C:/Users/DAVID/Code/onebusaway-ios';
const otpRoot = 'C:/Users/DAVID/Code/otpkit';

function parseStringsFile(filePath) {
  if (!fs.existsSync(filePath)) return {};
  const content = fs.readFileSync(filePath, 'utf8');
  const lines = content.split('\n');
  const entries = {};
  for (let line of lines) {
    line = line.trim();
    if (!line || line.startsWith('/*') || line.startsWith('//')) continue;
    const match = line.match(/^"([^"]+)"\s*=\s*"([^"]*)";/);
    if (match) {
      entries[match[1]] = match[2];
    }
  }
  return entries;
}

const bundles = [
  { name: 'Apps/OneBusAway InfoPlist', path: path.join(obaRoot, 'Apps/OneBusAway/ar.lproj/InfoPlist.strings') },
  { name: 'WatchApp InfoPlist', path: path.join(obaRoot, 'WatchApp/ar.lproj/InfoPlist.strings') },
  { name: 'OBAKitCore Strings', path: path.join(obaRoot, 'OBAKitCore/Strings/en.lproj/Localizable.strings') },
  { name: 'OBAKit Strings', path: path.join(obaRoot, 'OBAKit/Strings/en.lproj/Localizable.strings') },
  { name: 'OBAKit AppIntents', path: path.join(obaRoot, 'OBAKit/Strings/en.lproj/AppIntents.strings') },
  { name: 'OBAKit AppShortcuts', path: path.join(obaRoot, 'OBAKit/Strings/en.lproj/AppShortcuts.strings') },
  { name: 'OBAKitWatch Strings', path: path.join(obaRoot, 'OBAKitWatch/Strings/en.lproj/Localizable.strings') },
  { name: 'OBAWidget AppIntents', path: path.join(obaRoot, 'OBAWidget/Strings/en.lproj/AppIntents.strings') },
  { name: 'OTPKit Strings', path: path.join(otpRoot, 'OTPKit/Sources/OTPKit/Resources/en.lproj/Localizable.strings') }
];

let totalKeys = 0;
for (const b of bundles) {
  const entries = parseStringsFile(b.path);
  const count = Object.keys(entries).length;
  totalKeys += count;
  console.log(`${b.name}: ${count} keys`);
}
console.log(`TOTAL KEYS: ${totalKeys}`);
