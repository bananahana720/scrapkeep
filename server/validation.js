export const CONSENT_VERSION = "2026-09-05-v1";

export function consentText(brand) {
  return {
    email: `Email me ${brand} figurine news and launch updates.`,
    sms: `I agree to receive marketing texts about ${brand} figurines. Message frequency varies. Message and data rates may apply. Consent is not a condition of purchase. Reply STOP to opt out when messaging is enabled.`,
  };
}

export class RequestError extends Error {
  constructor(status, message) {
    super(message);
    this.status = status;
  }
}

function record(value, allowed) {
  return (
    value !== null &&
    typeof value === "object" &&
    !Array.isArray(value) &&
    Object.keys(value).every((key) => allowed.includes(key))
  );
}

export function parseLead(input) {
  if (
    !record(input, [
      "email",
      "phone",
      "consent",
      "heroClass",
      "source",
      "run",
      "website",
    ])
  ) {
    throw new RequestError(400, "Check the form and try again.");
  }
  if (typeof input.website !== "string" || input.website.length > 0) {
    throw new RequestError(400, "Unable to accept this submission.");
  }
  if (
    !record(input.consent, ["email", "sms"]) ||
    typeof input.consent.email !== "boolean" ||
    typeof input.consent.sms !== "boolean"
  ) {
    throw new RequestError(400, "Choose the updates you agree to receive.");
  }
  const email =
    typeof input.email === "string"
      ? input.email.trim().toLowerCase()
      : undefined;
  const phone =
    typeof input.phone === "string" ? input.phone.trim() : undefined;
  if (
    input.email !== undefined &&
    (!email ||
      email.length > 254 ||
      !/^[a-z0-9.!#$%&'*+/=?^_`{|}~-]+@[a-z0-9](?:[a-z0-9-]*[a-z0-9])?(?:\.[a-z0-9](?:[a-z0-9-]*[a-z0-9])?)+$/i.test(
        email,
      ) ||
      email.split("@")[0].length > 64 ||
      email.startsWith(".") ||
      email.includes("..") ||
      email.includes(".@"))
  ) {
    throw new RequestError(400, "Enter a valid email address.");
  }
  if (
    input.phone !== undefined &&
    (!phone || !/^\+[1-9]\d{7,14}$/.test(phone))
  ) {
    throw new RequestError(
      400,
      "Use an international phone number, such as +14155550123.",
    );
  }
  if (
    (!email && !phone) ||
    Boolean(email) !== input.consent.email ||
    Boolean(phone) !== input.consent.sms
  ) {
    throw new RequestError(
      400,
      "Add at least one contact and agree to updates for each contact provided.",
    );
  }
  if (
    !["scavenger", "engineer", "warden"].includes(input.heroClass) ||
    !["collection", "run-result"].includes(input.source)
  ) {
    throw new RequestError(400, "Choose a figurine and try again.");
  }
  const run = input.run;
  if (
    !record(run, ["seed", "score", "wave", "outcome"]) ||
    !Number.isSafeInteger(run.seed) ||
    run.seed < 0 ||
    run.seed > 0xffffffff ||
    !Number.isSafeInteger(run.score) ||
    run.score < 0 ||
    run.score > 1e12 ||
    !Number.isSafeInteger(run.wave) ||
    run.wave < 0 ||
    run.wave > 1e6 ||
    !["victory", "defeat", "gameover", "abandoned", "in-progress"].includes(
      run.outcome,
    )
  ) {
    throw new RequestError(
      400,
      "The run details are invalid. Reopen the form and try again.",
    );
  }
  return {
    email,
    phone,
    heroClass: input.heroClass,
    source: input.source,
    run: { ...run },
  };
}
