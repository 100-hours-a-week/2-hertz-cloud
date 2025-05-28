// k6 AI 서버 부하 테스트 스크립트 - 50명의 유저가 동시에 가입 요청

import http from 'k6/http';
import { check, sleep } from 'k6';
import { Counter, Trend } from 'k6/metrics';

// 사용자 정의 메트릭
const successCounter = new Counter('success_count');
const conflictCounter = new Counter('conflict_count');
const validationCounter = new Counter('validation_count');
const timeoutCounter = new Counter('timeout_count');
const totalRequestCounter = new Counter('total_requests');
const responseTimeTrend = new Trend('response_time_ms');

export let options = {
    scenarios: {
        signup_exact_30: {
          executor: 'shared-iterations',
          vus: 2,                // 동시에 실행할 가상 사용자 수
          iterations: 30,         // ✅ 총 요청 수 = 30회
          maxDuration: '2m',      // 여유 있는 실행 시간
        }
      },
    thresholds: {
      'success_count': ['count>=45'],
      'http_req_failed': ['rate<0.2'],
    },
  };

// 열거형 데이터
const AgeGroup = { AGE_20S: '20대', AGE_30S: '30대', AGE_40S: '40대', AGE_50S: '50대', AGE_60_PLUS: '60대 이상' };
const Gender = { MALE: '남자', FEMALE: '여자' };
const Religion = { NON_RELIGIOUS: '무교', CHRISTIANITY: '기독교', BUDDHISM: '불교', CATHOLICISM: '천주교', WON_BUDDHISM: '원불교', OTHER_RELIGION: '기타' };
const Smoking = { NO_SMOKING: '비흡연', SOMETIMES: '가끔 흡연', EVERYDAY: '매일 흡연', E_CIGARETTE: '전자담배', TRYING_TO_QUIT: '금연중' };
const Drinking = { NEVER: '전혀 안 마심', ONLY_IF_NEEDED: '필요할 때만 음주', SOMETIMES: '가끔 음주', OFTEN: '자주 음주', TRYING_TO_QUIT: '금주중' };
const MBTI = { ISTJ: 'ISTJ', ISFJ: 'ISFJ', INFJ: 'INFJ', INTJ: 'INTJ', ISTP: 'ISTP', ISFP: 'ISFP', INFP: 'INFP', INTP: 'INTP', ESTP: 'ESTP', ESFP: 'ESFP', ENFP: 'ENFP', ENTP: 'ENTP', ESTJ: 'ESTJ', ESFJ: 'ESFJ', ENFJ: 'ENFJ', ENTJ: 'ENTJ', UNKWON: 'MBTI 모름' };

function getKeysFromObject(obj) {
  return Object.keys(obj);
}
function getRandomFromArray(array) {
  return array[Math.floor(Math.random() * array.length)];
}
function getRandomSubArray(array, maxItems) {
  const count = Math.floor(Math.random() * maxItems) + 1;
  const shuffled = [...array].sort(() => 0.5 - Math.random());
  return shuffled.slice(0, count);
}

function generateRandomAiServerRequest(userIndex) {
  const personalityOptions = ["CUTE", "RELIABLE", "SMILES_OFTEN", "DOESNT_SWEAR", "NICE_VOICE", "TALKATIVE", "GOOD_LISTENER", "ACTIVE", "QUIET", "PASSIONATE", "CALM", "WITTY", "POLITE", "SERIOUS", "UNIQUE", "FREE_SPIRITED", "METICULOUS", "SENSITIVE", "COOL", "SINCERE", "LOYAL", "OPEN_MINDED", "AFFECTIONATE", "CONSERVATIVE", "CONSIDERATE", "NEAT", "POSITIVE", "FRUGAL", "CHARACTERFUL", "HONEST", "PLAYFUL", "DILIGENT", "FAMILY_ORIENTED", "COMPETENT", "SELF_MANAGING", "RESPONSIVE", "WORKAHOLIC", "SOCIABLE", "LONER", "COMPETITIVE", "EMPATHETIC"];
  const interestOptions = ["MOVIES", "NETFLIX", "VARIETY_SHOWS", "HOME_CAFE", "CHATTING", "DANCE", "SPACE_OUT", "COOKING", "BAKING", "DRAWING", "PLANT_PARENTING", "INSTRUMENT", "PHOTOGRAPHY", "FORTUNE_TELLING", "MAKEUP", "NAIL_ART", "INTERIOR", "CLEANING", "SCUBA_DIVING", "SKATEBOARDING", "SNEAKER_COLLECTION", "STOCKS", "CRYPTO"];
  const foodOptions = ["TTEOKBOKKI", "MEXICAN", "CHINESE", "JAPANESE", "KOREAN", "VEGETARIAN", "MEAT_LOVER", "FRUIT", "WESTERN", "STREET_FOOD", "BAKERY", "HAMBURGER", "PIZZA", "BRUNCH", "ROOT_VEGETABLES", "CHICKEN", "VIETNAMESE", "SEAFOOD", "THAI", "SPICY_FOOD"];
  const sportsOptions = ["BASEBALL", "SOCCER", "HIKING", "RUNNING", "GOLF", "GYM", "PILATES", "HOME_TRAINING", "CLIMBING", "CYCLING", "BOWLING", "BILLIARDS", "YOGA", "TENNIS", "SQUASH", "BADMINTON", "BASKETBALL", "SURFING", "CROSSFIT", "VOLLEYBALL", "PINGPONG", "FUTSAL", "FISHING", "SKI", "BOXING", "SNOWBOARD", "SHOOTING", "JIUJITSU", "SWIMMING", "MARATHON"];
  const petOptions = ["DOG", "CAT", "REPTILE", "AMPHIBIAN", "BIRD", "FISH", "LIKE_BUT_NOT_HAVE", "HAMSTER", "RABBIT", "NONE", "WANT_TO_HAVE"];
  const selfDevOptions = ["READING", "STUDYING", "CAFE_STUDY", "LICENSE_STUDY", "LANGUAGE_LEARNING", "INVESTING", "MIRACLE_MORNING", "CAREER_DEVELOPMENT", "DIET", "MINDFULNESS", "LIFE_OPTIMIZATION", "WRITING"];
  const hobbyOptions = ["GAMING", "MUSIC", "OUTDOOR", "MOVIES", "DRAMA", "CHATTING", "SPACE_OUT", "APPRECIATION", "DANCE", "COOKING", "BAKING", "DRAWING", "PLANT_CARE", "INSTRUMENT", "PHOTOGRAPHY", "WEBTOON", "MAKEUP", "INTERIOR", "CLEANING", "SCUBA_DIVING", "COLLECTING", "STOCKS"];

  return {
    userId: userIndex,
    emailDomain: `test${userIndex}@kakaotech.com`,
    gender: getRandomFromArray(getKeysFromObject(Gender)),
    ageGroup: getRandomFromArray(getKeysFromObject(AgeGroup)),
    MBTI: getRandomFromArray(getKeysFromObject(MBTI)),
    religion: getRandomFromArray(getKeysFromObject(Religion)),
    smoking: getRandomFromArray(getKeysFromObject(Smoking)),
    drinking: getRandomFromArray(getKeysFromObject(Drinking)),
    personality: getRandomSubArray(personalityOptions, 3),
    preferredPeople: getRandomSubArray(personalityOptions, 3),
    currentInterests: getRandomSubArray(interestOptions, 3),
    favoriteFoods: getRandomSubArray(foodOptions, 3),
    likedSports: getRandomSubArray(sportsOptions, 3),
    pets: getRandomSubArray(petOptions, 3),
    selfDevelopment: getRandomSubArray(selfDevOptions, 3),
    hobbies: getRandomSubArray(hobbyOptions, 2)
  };
}
function generateRequestData() {
    const userIndex = Math.floor(Math.random() * 10000); // 랜덤 유저 ID 생성
    return generateRandomAiServerRequest(userIndex);
  }
  
  export default function () {
    const requestData = generateRequestData();
    const requestBody = JSON.stringify(requestData);
  
    const response = http.post(
      'http://34.81.212.3:8000/api/v1/users',
      requestBody,
      { headers: { 'Content-Type': 'application/json' }, timeout: '20s' }
    );
  
    responseTimeTrend.add(response.timings.duration);
    totalRequestCounter.add(1);
    check(response, {
      'status is 200 or 201': (r) => r.status === 200 || r.status === 201,
      'status is 409 (conflict)': (r) => r.status === 409,
      'status is 422 (validation error)': (r) => r.status === 422,
      'response has valid format': (r) => {
        try {
          JSON.parse(r.body);
          return true;
        } catch (_) {
          return false;
        }
      }
    });
  
    try {
      const parsed = JSON.parse(response.body);
      if (response.status === 200 || response.status === 201) successCounter.add(1);
      else if (response.status === 409) conflictCounter.add(1);
      else if (response.status === 422) validationCounter.add(1);
      else timeoutCounter.add(1);
    } catch (_) {
      timeoutCounter.add(1);
    }
  }
  
  export function handleSummary(data) {
    const safe = (name) => data.metrics[name]?.values ?? {};
  
    return {
      stdout: JSON.stringify({
        summary: {
          vus: 'dynamic ramping up to 50 arrivals/minute',
          totalRequests: safe('total_requests').count ?? 0,
          success: safe('success_count').count ?? 0,
          conflicts: safe('conflict_count').count ?? 0,
          validationErrors: safe('validation_count').count ?? 0,
          timeouts: safe('timeout_count').count ?? 0,
          response: {
            min: (safe('response_time_ms').min ?? 0).toFixed(2),
            avg: (safe('response_time_ms').avg ?? 0).toFixed(2),
            med: (safe('response_time_ms').med ?? 0).toFixed(2),
            p90: (safe('response_time_ms')['p(90)'] ?? 0).toFixed(2),
            p95: (safe('response_time_ms')['p(95)'] ?? 0).toFixed(2),
            max: (safe('response_time_ms').max ?? 0).toFixed(2),
          }
        }
      }, null, 2)
    };
  }
  