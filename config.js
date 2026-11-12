// 템플릿 공유 저장소 · 배너 등록 · 공유 URL 기능용 Supabase 설정
// Supabase 대시보드 > Project Settings > API 에서 복사해 넣으세요.
//   supabaseUrl     : Project URL (예: https://abcdefgh.supabase.co)
//   supabaseAnonKey : anon / publishable 키 (브라우저에 공개돼도 되는 키)
// ⚠ service_role / secret 키는 절대 넣지 마세요. 넣으면 앱이 사용을 거부해요.
// 비워 두면 등록 · 공유 기능만 꺼지고 나머지 기능은 그대로 동작해요.
window.BANNER_CONFIG = {
  supabaseUrl: 'https://vusgutbijcnoniuamume.supabase.co',
  supabaseAnonKey: 'sb_publishable_ak0xPWfCJaUobAXCQF3nMA_nIuE30pW',
  // 배너 제작 화면의 [배너 등록하고 공유 URL 만들기] 기능 표시 여부
  //   false: 숨김 (운영자는 문구만 고쳐서 PNG/JPG 다운로드)  /  true: 다시 보이게
  enableShare: false,
};
