import {exactKeys, hex64, object, utcTime} from './staff-contract.ts';

export const reviewId = /^[a-f0-9]{8}-[a-f0-9]{4}-[1-8][a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$/i;
export const reviewCursor = /^[A-Za-z0-9_-]+\.[a-f0-9]{64}$/;
export const reviewTopics = ['everyday', 'work', 'study', 'hobbies', 'language-practice'] as const;
export type ReviewLanguage = 'ta' | 'en';
export type ReviewTopic = typeof reviewTopics[number];
export type ReviewSummary = {id: string; alias: string; state: 'submitted'; languages: ReviewLanguage[]; submittedAt: string; voiceSampleAvailable: boolean};
export type ReviewPage = {items: ReviewSummary[]; nextCursor: string | null; decisionsEnabled: boolean};
export type ReviewApplication = {id: string; alias: string; state: 'submitted'; bio: string; topics: ReviewTopic[]; languages: ReviewLanguage[];
  submittedAt: string; materialVersion: string; adultStatus: 'self_declared'; voiceSample: {contentType: 'audio/wav'; byteLength: number} | null};
export type ReviewDetail = {application: ReviewApplication; decisionsEnabled: boolean};
const languages = (value: unknown): value is ReviewLanguage[] => Array.isArray(value) && value.length >= 1 && value.length <= 2 &&
  new Set(value).size === value.length && value.every(language => language === 'ta' || language === 'en');
function summaryFields(value: Record<string, unknown>): boolean {
  return typeof value.id === 'string' && reviewId.test(value.id) && typeof value.alias === 'string' && value.alias.length >= 1 && value.alias.length <= 80 &&
    value.state === 'submitted' && languages(value.languages) && utcTime(value.submittedAt);
}
export function reviewPageValue(value: unknown): value is ReviewPage {
  return object(value) && exactKeys(value, ['items', 'nextCursor', 'decisionsEnabled']) && typeof value.decisionsEnabled === 'boolean' &&
    (value.nextCursor === null || typeof value.nextCursor === 'string' && value.nextCursor.length <= 2048 && reviewCursor.test(value.nextCursor)) &&
    Array.isArray(value.items) && value.items.length <= 20 && new Set(value.items.map(item => object(item) ? item.id : null)).size === value.items.length &&
    value.items.every(item => object(item) && exactKeys(item, ['id', 'alias', 'state', 'languages', 'submittedAt', 'voiceSampleAvailable']) &&
      summaryFields(item) && typeof item.voiceSampleAvailable === 'boolean');
}
export function reviewDetailValue(value: unknown): value is ReviewDetail {
  if (!object(value) || !exactKeys(value, ['application', 'decisionsEnabled']) || typeof value.decisionsEnabled !== 'boolean' || !object(value.application)) return false;
  const app = value.application;
  return exactKeys(app, ['id', 'alias', 'state', 'bio', 'topics', 'languages', 'submittedAt', 'materialVersion', 'adultStatus', 'voiceSample']) && summaryFields(app) &&
    typeof app.bio === 'string' && [...app.bio].length <= 1000 && Array.isArray(app.topics) && app.topics.length <= 5 && new Set(app.topics).size === app.topics.length &&
    app.topics.every(topic => reviewTopics.includes(topic)) && typeof app.materialVersion === 'string' && hex64.test(app.materialVersion) && app.adultStatus === 'self_declared' &&
    (app.voiceSample === null || object(app.voiceSample) && exactKeys(app.voiceSample, ['contentType', 'byteLength']) && app.voiceSample.contentType === 'audio/wav' &&
      typeof app.voiceSample.byteLength === 'number' && Number.isInteger(app.voiceSample.byteLength) && app.voiceSample.byteLength >= 44 && app.voiceSample.byteLength <= 2097152);
}
