import {setGlobalOptions} from "firebase-functions";
import {defineSecret} from "firebase-functions/params";
import {onCall, HttpsError} from "firebase-functions/v2/https";
import {onDocumentCreated} from "firebase-functions/v2/firestore";
import * as logger from "firebase-functions/logger";
import * as admin from "firebase-admin";

setGlobalOptions({maxInstances: 10});

admin.initializeApp();

const openaiApiKey = defineSecret("OPENAI_API_KEY");

type ProfileSnapshotV1 = {
  v: number;
  selections: Record<string, string>;
  ts: number;
};

type AICompatibilityInsight = {
  percent: number;
  strengths: string[];
  frictions: string[];
  summary: string;
  forecasts?: ForecastItem[];
  icebreakers?: IcebreakerItem[];
};

type IcebreakerItem = {
  topic: string;
  prompt: string;
};

type ForecastItem = {
  id: "financial" | "stress" | "social";
  title: string;
  risk: "DİKKAT" | "ORTA RİSK" | "HAFİF";
  description: string;
  tip: string;
};

type AISelfProfileInsight = {
  summary: string;
  aboutYou?: string[];
  gentleReminders: string[];
  traitBreakdown?: Array<{
    id: string;
    title: string;
    percent: number; // 0-100
    description: string;
  }>;
};

type TraitBreakdownItem = {
  id: string;
  title: string;
  percent: number;
  description: string;
};

const ORDERED_PROFILE_LABELS: Array<{id: string; title: string}> = [
  {id: "messageTempo", title: "Partner mesajına geç dönme"},
  {id: "repairAfterConflict", title: "Küçük bir tartışma çıktı"},
  {id: "boundaryStyle", title: "Bir konuda kırıldın"},
  {id: "closenessNeed", title: "Yeni biriyle tanışıyorsun"},
  {id: "jealousyTrigger", title: "Partnerin karşı cins biriyle sık görüşüyor"},
];

/**
 * Formats a profile snapshot into a stable, human-readable bullet list.
 *
 * @param {ProfileSnapshotV1} snapshot Profile snapshot payload (v1).
 * @return {string} Bullet list string.
 */
function prettySelections(snapshot: ProfileSnapshotV1): string {
  return ORDERED_PROFILE_LABELS.map(({id, title}) => {
    const value = snapshot.selections[id] ?? "—";
    return `- ${title}: ${value}`;
  }).join("\n");
}

/**
 * Computes deterministic overlap score from profile selections.
 * This protects the compatibility percent from becoming "flat"
 * when LLM output happens to repeat similar values.
 *
 * @param {ProfileSnapshotV1} me User snapshot.
 * @param {ProfileSnapshotV1} partner Partner snapshot.
 * @return {number} 0-100 overlap percentage.
 */
function selectionOverlapPercent(
  me: ProfileSnapshotV1,
  partner: ProfileSnapshotV1
): number {
  let comparable = 0;
  let exactMatches = 0;

  for (const {id} of ORDERED_PROFILE_LABELS) {
    const a = (me.selections[id] ?? "").trim();
    const b = (partner.selections[id] ?? "").trim();
    if (!a || !b) continue;
    comparable += 1;
    if (a === b) exactMatches += 1;
  }

  // Relationship fit is not pure "same answer = good".
  // Even with different answers, couples can be highly compatible.
  // Keep overlap in a softer band and avoid harsh drops.
  if (comparable === 0) return 70;
  const matchRatio = exactMatches / comparable; // 0..1
  return Math.round(58 + matchRatio * 34); // 58..92
}

/**
 * Clamps numeric percent to 0-100 integer.
 *
 * @param {number} value Any numeric value.
 * @return {number} Integer in [0, 100].
 */
function clampPercent(value: number): number {
  if (!Number.isFinite(value)) return 0;
  return Math.max(0, Math.min(100, Math.round(value)));
}

/**
 * Builds fallback forecast cards when model omits them.
 *
 * @param {string[]} frictions Compatibility friction lines.
 * @return {ForecastItem[]} Three forecast cards.
 */
function fallbackForecasts(frictions: string[]): ForecastItem[] {
  const templates: Array<{
    id: ForecastItem["id"];
    title: string;
    risk: ForecastItem["risk"];
    tip: string;
  }> = [
    {
      id: "financial",
      title: "Finansal Yaklaşım",
      risk: "DİKKAT",
      tip: "Bütçe konuşmalarını ortak hedef diliyle yapın.",
    },
    {
      id: "stress",
      title: "Stres Yönetimi",
      risk: "ORTA RİSK",
      tip: "Tansiyon yükselince kısa mola ve sakin dönüş kuralı koyun.",
    },
    {
      id: "social",
      title: "Sosyal Enerji",
      risk: "HAFİF",
      tip: "Sosyal ve sakin zamanlar arasında denge kurun.",
    },
  ];

  return templates.map((t, idx) => ({
    id: t.id,
    title: t.title,
    risk: t.risk,
    description:
      frictions[idx] ??
      "Belirgin bir sürtüşme görünmüyor; açık iletişimle denge korunabilir.",
    tip: t.tip,
  }));
}

/**
 * Builds fallback conversation starters from compatibility output.
 *
 * @param {string[]} strengths Positive overlap lines.
 * @return {IcebreakerItem[]} Conversation starter cards.
 */
function fallbackIcebreakers(strengths: string[]): IcebreakerItem[] {
  const defaults: IcebreakerItem[] = [
    {
      topic: "Hafta Sonu Planları",
      prompt:
        "Birlikte keyif alacağımız bir hafta sonu planı sence ne olur?",
    },
    {
      topic: "Günlük Rutin",
      prompt:
        "Günün en keyif aldığın kısmı hangisi ve o anı özel yapan şey ne?",
    },
    {
      topic: "Müzik / Film",
      prompt:
        "Son dönemde seni gerçekten etkileyen bir şarkı veya film neydi?",
    },
    {
      topic: "Seyahat / Keşif",
      prompt:
        "Kısa bir kaçamak şansın olsa ilk hangi rotayı seçerdin?",
    },
  ];

  if (strengths.length === 0) return defaults;

  return defaults.map((item, idx) => {
    const s = strengths[idx % strengths.length];
    return {
      topic: item.topic,
      prompt: `${item.prompt} (İkinizde öne çıkan ortak alan: ${s})`,
    };
  });
}

/**
 * Calls OpenAI Responses API and returns the first JSON text payload.
 *
 * @param {object} args Arguments.
 * @param {string} args.apiKey OpenAI API key.
 * @param {string} args.system System prompt.
 * @param {string} args.user User prompt.
 * @return {Promise<string>} JSON string from the model.
 */
async function callOpenAIJson(args: {
  apiKey: string;
  system: string;
  user: string;
}): Promise<string> {
  const body = {
    model: "gpt-4o-mini",
    input: [
      {role: "system", content: args.system},
      {role: "user", content: args.user},
    ],
    text: {format: {type: "json_object"}},
    temperature: 0.4,
  };

  const resp = await fetch("https://api.openai.com/v1/responses", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      "Authorization": `Bearer ${args.apiKey}`,
    },
    body: JSON.stringify(body),
  });

  const text = await resp.text();
  if (!resp.ok) {
    logger.error("OpenAI error", {status: resp.status, body: text});

    // Try to surface actionable errors to the client (without leaking secrets).
    try {
      const errJson = JSON.parse(text) as {
        error?: {code?: string; type?: string; message?: string};
      };
      const code = errJson.error?.code ?? "";
      const type = errJson.error?.type ?? "";

      if (
        resp.status === 429 &&
        (code === "insufficient_quota" || type === "insufficient_quota")
      ) {
        throw new HttpsError(
          "resource-exhausted",
          "OpenAI kotasi yetersiz; OpenAI hesabinda billing/limiti kontrol et."
        );
      }

      if (resp.status === 401) {
        throw new HttpsError(
          "failed-precondition",
          "OpenAI anahtarı geçersiz."
        );
      }
    } catch (e) {
      if (e instanceof HttpsError) throw e;
      // ignore JSON parse failures and fall through
    }

    throw new HttpsError("internal", "OpenAI isteği başarısız");
  }

  const parsed = JSON.parse(text) as {
    output?: Array<{content?: Array<{type?: string; text?: string}>}>;
  };

  for (const item of parsed.output ?? []) {
    for (const c of item.content ?? []) {
      if (c.type === "output_text" && c.text) return c.text;
    }
  }

  throw new HttpsError("internal", "OpenAI response missing text");
}

/**
 * Callable function: analyzes compatibility between two profile snapshots.
 */
export const analyzeCompatibility = onCall(
  {
    region: "europe-west1",
    secrets: [openaiApiKey],
    enforceAppCheck: false,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Giriş gerekli");
    }

    const data = request.data as {
      me?: ProfileSnapshotV1;
      partner?: ProfileSnapshotV1;
      privateNote?: string;
    };

    const me = data.me;
    const partner = data.partner;
    if (!me || !partner) {
      throw new HttpsError("invalid-argument", "me ve partner zorunlu");
    }
    if (me.v !== 1 || partner.v !== 1) {
      throw new HttpsError(
        "invalid-argument",
        "Desteklenmeyen snapshot versiyonu"
      );
    }

    const apiKey = openaiApiKey.value();
    if (!apiKey) {
      throw new HttpsError(
        "failed-precondition",
        "OPENAI_API_KEY yok"
      );
    }

    const system = [
      "Sen bir ilişki uyumu analisti yardımcısısın.",
      "Yargılayıcı değil, kısa ve faydalı konuş.",
      "Çıktı kesin hüküm değil, eğilim analizi olsun.",
      "Türkçe yanıt ver.",
    ].join(" ");

    const privateNote = (data.privateNote ?? "").trim();
    const privateNoteBlock =
      privateNote.length > 0 ?
        [
          "",
          "",
          "Benim özel notum (kimsenin görmediği, sadece benim için):",
          privateNote,
          "",
        ].join("\n") :
        "";

    const user = [
      "İki profilin 5 sorudaki seçimleri aşağıda.",
      "",
      "Ben:",
      prettySelections(me),
      "",
      "Karşı taraf:",
      prettySelections(partner),
      privateNoteBlock,
      "",
      "JSON formatında yanıtla:",
      "{",
      "  \"percent\": 0-100,",
      "  \"strengths\": [\"...\"],",
      "  \"frictions\": [\"...\"],",
      "  \"summary\": \"2-3 cümle kısa özet\",",
      "  \"forecasts\": [",
      [
        "    {\"id\":\"financial\",\"title\":\"Finansal Yaklaşım\",",
        "\"risk\":\"DİKKAT\",\"description\":\"...\",\"tip\":\"...\"},",
      ].join(""),
      [
        "    {\"id\":\"stress\",\"title\":\"Stres Yönetimi\",",
        "\"risk\":\"ORTA RİSK\",\"description\":\"...\",\"tip\":\"...\"},",
      ].join(""),
      [
        "    {\"id\":\"social\",\"title\":\"Sosyal Enerji\",",
        "\"risk\":\"HAFİF\",\"description\":\"...\",\"tip\":\"...\"}",
      ].join(""),
      "  ]",
      "  \"icebreakers\": [",
      "    {\"topic\":\"...\",\"prompt\":\"...\"},",
      "    {\"topic\":\"...\",\"prompt\":\"...\"},",
      "    {\"topic\":\"...\",\"prompt\":\"...\"},",
      "    {\"topic\":\"...\",\"prompt\":\"...\"}",
      "  ]",
      "}",
      "",
      "Kurallar:",
      "- strengths ve frictions maddeleri kısa olsun (maks 6 madde).",
      "- summary yumuşak dille yazılsın, kesin teşhis/itham yok.",
      "- forecasts her zaman 3 eleman olsun: financial, stress, social.",
      "- risk sadece DİKKAT / ORTA RİSK / HAFİF olsun.",
      "- tip alanı somut, tek cümle iletişim önerisi olsun.",
      "- icebreakers alanı 4 eleman olsun.",
      [
        "- icebreakers: topic kısa başlık olsun;",
        " prompt doğrudan sorulabilir tek soru olsun.",
      ].join(""),
      "- Soru tonu doğal, tanışma aşamasına uygun ve yargısız olsun.",
      [
        "- private note varsa, sadece 'ben' tarafının içgörüsü olarak kullan;",
        " karşı taraf hakkında iddia üretme.",
      ].join(""),
    ].join("\n");

    const jsonText = await callOpenAIJson({apiKey, system, user});

    let insight: AICompatibilityInsight;
    try {
      insight = JSON.parse(jsonText) as AICompatibilityInsight;
    } catch (e) {
      logger.error("Failed to parse model JSON", {jsonText, e});
      throw new HttpsError("internal", "Model JSON parse failed");
    }

    if (
      typeof insight.percent !== "number" ||
      !Array.isArray(insight.strengths) ||
      !Array.isArray(insight.frictions) ||
      typeof insight.summary !== "string"
    ) {
      throw new HttpsError("internal", "Model JSON shape invalid");
    }

    if (!Array.isArray(insight.forecasts) || insight.forecasts.length !== 3) {
      insight.forecasts = fallbackForecasts(insight.frictions);
    }
    if (!Array.isArray(insight.icebreakers) || insight.icebreakers.length < 3) {
      insight.icebreakers = fallbackIcebreakers(insight.strengths);
    }

    // Blend model score with deterministic overlap from raw answers.
    // Keep model weight higher so nuanced/complementary dynamics can surface.
    const overlapPercent = selectionOverlapPercent(me, partner);
    const modelPercent = clampPercent(insight.percent);
    const blendedPercent = clampPercent(
      modelPercent * 0.75 + overlapPercent * 0.25
    );

    // If strengths are not fewer than frictions, do not show overly low scores.
    // This prevents healthy-but-different couples
    // from receiving discouraging lows.
    const strengthsCount = insight.strengths.length;
    const frictionsCount = insight.frictions.length;
    const softFloor = strengthsCount >= frictionsCount ? 72 : 62;
    insight.percent = Math.min(96, Math.max(softFloor, blendedPercent));

    logger.info("Compatibility score blended", {
      uid: request.auth.uid,
      modelPercent,
      blendedPercent,
      softFloor,
      finalPercent: insight.percent,
      strengthsCount,
      frictionsCount,
      overlapPercent,
    });

    return insight;
  }
);

/**
 * Callable: single-user profile readback from 10 “subtle” questions.
 */
export const analyzeSelfProfile = onCall(
  {
    region: "europe-west1",
    secrets: [openaiApiKey],
    enforceAppCheck: false,
  },
  async (request) => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Giriş gerekli");
    }

    const data = request.data as {
      me?: ProfileSnapshotV1;
      privateNote?: string;
    };

    const me = data.me;
    if (!me) {
      throw new HttpsError("invalid-argument", "me zorunlu");
    }
    if (me.v !== 1) {
      throw new HttpsError(
        "invalid-argument",
        "Desteklenmeyen snapshot versiyonu"
      );
    }

    const apiKey = openaiApiKey.value();
    if (!apiKey) {
      throw new HttpsError(
        "failed-precondition",
        "OPENAI_API_KEY yok"
      );
    }

    const system = [
      "Sen kısa ve nazik bir ilişki-kişilik özet asistanısın.",
      "Girdi 5 maddelik kısa ankete dayanır; kesin tanı veya etiket yok.",
      "Türkçe, yargısız, destekleyici yaz.",
      "Çıktıda küçümseyici veya aşağılayıcı dil kullanma.",
    ].join(" ");

    const privateNote = (data.privateNote ?? "").trim();
    const privateNoteBlock =
      privateNote.length > 0 ?
        [
          "",
          "Kullanıcının özel notu (sadece kullanıcıya özel):",
          privateNote,
          "",
        ].join("\n") :
        "";

    const user = [
      "Aşağıda kullanıcının 5 soruya verdiği seçimler var.",
      "",
      prettySelections(me),
      privateNoteBlock,
      "",
      "Bu seçimlere dayanarak kullanıcıya özel tek bir güçlü anlatım üret.",
      "",
      "JSON formatında yanıtla:",
      "{",
      [
        "  \"summary\":",
        "\"Türkçe tek sürekli anlatım: seçimleri yansıtan özet;",
        " ilişkiye yaklaşım, iletişim, sınırlar, yakınlık ihtiyacı gibi temaları",
        " ayrı bölüm YAZMADAN bu metinde doğal tek akışta veya kısa maddeler içinde;",
        " 5–12 cümle; yargılayıcı olma.\",",
      ].join(""),
      "  \"aboutYou\": [],",
      "  \"gentleReminders\": [\"en fazla 3 madde\"],",
      "  \"traitBreakdown\": [",
      [
        "    {\"id\":\"introversion\",\"title\":\"INTROVERSION\",",
        "\"percent\":0,\"description\":\"...\"},",
      ].join(""),
      [
        "    {\"id\":\"creativity\",\"title\":\"CREATIVITY\",",
        "\"percent\":0,\"description\":\"...\"},",
      ].join(""),
      [
        "    {\"id\":\"logic\",\"title\":\"LOGIC\",",
        "\"percent\":0,\"description\":\"...\"},",
      ].join(""),
      [
        "    {\"id\":\"empathy\",\"title\":\"EMPATHY\",",
        "\"percent\":0,\"description\":\"...\"},",
      ].join(""),
      [
        "    {\"id\":\"ambition\",\"title\":\"AMBITION\",",
        "\"percent\":0,\"description\":\"...\"}",
      ].join(""),
      "  ]",
      "}",
      "",
      "Kurallar:",
      "- aboutYou hep boş dizi (eski uyumluluk alanıdır).",
      "- Tekrarlayan ikinci blok YOK: ilişkiye dair ne söylenecekse hep summary içinde olsun.",
      "- gentleReminders isteğe bağlı; fazlaysa kısalt.",
      [
        "- traitBreakdown her zaman 5 eleman içersin",
        " (introversion, creativity, logic, empathy, ambition).",
      ].join(""),
      [
        "- percent 0-100 arası olsun; yuvarla;",
        " çok uç değerlerden kaçın (genelde 25-95 aralığı).",
      ].join(""),
      "- description 1-2 kısa cümle olsun.",
      "- Kesin kişilik etiketi kullanma (ör. narcist).",
      [
        "- Özel not varsa yalnızca kullanıcıyla ilişkili iç görü olarak",
        " kullan; üçüncü şahıs hakkında varsayım yapma.",
      ].join(""),
    ].join("\n");

    const jsonText = await callOpenAIJson({apiKey, system, user});

    let insight: AISelfProfileInsight;
    try {
      insight = JSON.parse(jsonText) as AISelfProfileInsight;
    } catch (e) {
      logger.error("Failed to parse model JSON", {jsonText, e});
      throw new HttpsError("internal", "Model JSON parse failed");
    }

    if (typeof insight.summary !== "string" || !Array.isArray(insight.gentleReminders)) {
      throw new HttpsError("internal", "Model JSON shape invalid");
    }

    const aboutYou = insight.aboutYou;
    if (
      aboutYou !== undefined &&
      !aboutYou.every((x: unknown) => typeof x === "string")
    ) {
      throw new HttpsError("internal", "Model JSON shape invalid");
    }

    const maybeTraitBreakdown = insight.traitBreakdown;
    if (Array.isArray(maybeTraitBreakdown)) {
      const tb = maybeTraitBreakdown as TraitBreakdownItem[];
      if (tb.length !== 5) {
        throw new HttpsError("internal", "Model JSON traitBreakdown invalid");
      }
      for (const t of tb) {
        if (
          typeof t?.id !== "string" ||
          typeof t?.title !== "string" ||
          typeof t?.percent !== "number" ||
          typeof t?.description !== "string"
        ) {
          throw new HttpsError("internal", "Model JSON traitBreakdown invalid");
        }
      }
    }

    return {
      summary: insight.summary,
      aboutYou: insight.aboutYou ?? [],
      gentleReminders: insight.gentleReminders,
      traitBreakdown: insight.traitBreakdown,
    };
  }
);

/**
 * Bir kullanıcı uyum puanını yayınladığında hedefe push bildirimi (FCM token gerekir).
 */
export const notifyTargetOnCompatibilityRating = onDocumentCreated(
  {
    document: "compatibilityRatings/{ratingId}",
    region: "europe-west1",
  },
  async (event) => {
    const snap = event.data;
    if (!snap) {
      return;
    }
    const data = snap.data();
    const targetUID = data?.targetUID as string | undefined;
    const raterUID = data?.raterUID as string | undefined;
    if (!targetUID || !raterUID || targetUID === raterUID) {
      return;
    }

    const nameRaw = data?.raterPublicName;
    const name =
      typeof nameRaw === "string" && nameRaw.trim().length > 0 ?
        nameRaw.trim() :
        "Birisi";

    const tokenSnap = await admin
      .firestore()
      .doc(`userPushTokens/${targetUID}`)
      .get();
    const token = tokenSnap.get("token") as string | undefined;
    if (!token) {
      logger.info("compat rating notify: target has no FCM token", {targetUID});
      return;
    }

    try {
      await admin.messaging().send({
        token,
        notification: {
          title: "VibeCheck",
          body: `${name} seni puanladı — sen de onu puanla.`,
        },
        data: {
          type: "compatibility_rating",
          ratingDocId: snap.id,
          pairKey: typeof data?.pairKey === "string" ? data.pairKey : "",
          raterUID,
        },
        apns: {
          payload: {
            aps: {
              sound: "default",
            },
          },
        },
      });
    } catch (e) {
      logger.error("compat rating notify FCM error", {e, targetUID});
    }
  }
);
