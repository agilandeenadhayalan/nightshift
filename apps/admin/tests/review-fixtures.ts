// Synthetic data for test harnesses only. No fixture routes exist in the app.
export const applicationId = '1a1eec02-9d54-4c93-8806-5b9a763785d1';
export const secondId = '2a1eec02-9d54-4c93-8806-5b9a763785d2';
export const thirdId = '3a1eec02-9d54-4c93-8806-5b9a763785d3';
export const materialVersion = 'c'.repeat(64);
export const nextCursor = `c3ludGhldGlj.${'d'.repeat(64)}`;
export const summary = {id: applicationId, alias: 'Applicant Moon', state: 'submitted', languages: ['en'], submittedAt: '2026-11-20T10:00:00.000Z', voiceSampleAvailable: true};
export const second = {...summary, id: secondId, alias: 'Applicant Leaf', languages: ['ta']};
export const third = {...summary, id: thirdId, alias: 'Applicant Wave'};
export const page = {items: [summary, second], nextCursor, decisionsEnabled: false};
export const sampleBytes = () => {
  const bytes = Buffer.alloc(32044);
  bytes.write('RIFF', 0); bytes.writeUInt32LE(bytes.length - 8, 4); bytes.write('WAVEfmt ', 8); bytes.writeUInt32LE(16, 16);
  bytes.writeUInt16LE(1, 20); bytes.writeUInt16LE(1, 22); bytes.writeUInt32LE(8000, 24); bytes.writeUInt32LE(16000, 28);
  bytes.writeUInt16LE(2, 32); bytes.writeUInt16LE(16, 34); bytes.write('data', 36); bytes.writeUInt32LE(32000, 40);
  return bytes;
};
export const detail = {application: {id: applicationId, alias: summary.alias, state: 'submitted', bio: 'I enjoy everyday conversations and language practice.', topics: ['everyday', 'language-practice'], languages: ['en'],
  submittedAt: summary.submittedAt, materialVersion, adultStatus: 'self_declared', voiceSample: {contentType: 'audio/wav', byteLength: 32044}}, decisionsEnabled: false};
