// https://docs.scriptable.app/
//
// Setup:
// 1. Copy the contents of ~/.codex/auth.json.
// 2. Run this script in Scriptable and paste the JSON when prompted.
// 3. Add a small Scriptable widget and select this script.

const USAGE_URL = "https://chatgpt.com/backend-api/wham/usage";
const CREDENTIALS_KEY = "com.liu.scriptable.codex.credentials";
const TIME_ZONE = "Asia/Shanghai";
const REFRESH_INTERVAL_MS = 15 * 60 * 1000;

const COLORS = {
  background: new Color("111827"),
  secondaryBackground: new Color("1f2937"),
  primary: new Color("f9fafb"),
  secondary: new Color("9ca3af"),
  usage: new Color("34d399"),
  resets: new Color("60a5fa"),
  error: new Color("f87171"),
};

async function run() {
  let credentials = loadCredentials();

  if (config.runsInApp) {
    if (credentials) {
      const action = await chooseAction();
      if (action === -1) return;
      if (action === 1) {
        credentials = await promptForCredentials();
        if (!credentials) return;
      }
    } else {
      credentials = await promptForCredentials();
      if (!credentials) return;
    }
  }

  if (!credentials) {
    await showWidget(createErrorWidget("Setup required", "Run the script to add auth.json"));
    return;
  }

  try {
    const usage = await fetchUsage(credentials);
    await showWidget(createUsageWidget(usage));
  } catch (error) {
    if (config.runsInApp && isAuthenticationError(error)) {
      const updatedCredentials = await promptForCredentials(
        "The saved access token has expired. Paste the latest auth.json.",
      );
      if (!updatedCredentials) return;

      try {
        const usage = await fetchUsage(updatedCredentials);
        await showWidget(createUsageWidget(usage));
        return;
      } catch (retryError) {
        error = retryError;
      }
    }

    await showWidget(createErrorWidget(...errorContent(error)));
  }
}

function loadCredentials() {
  if (!Keychain.contains(CREDENTIALS_KEY)) return null;

  try {
    const credentials = JSON.parse(Keychain.get(CREDENTIALS_KEY));
    if (!credentials.accessToken) return null;
    return credentials;
  } catch (_) {
    return null;
  }
}

async function chooseAction() {
  const alert = new Alert();
  alert.title = "Codex Usage";
  alert.addAction("Preview widget");
  alert.addAction("Update auth.json");
  alert.addCancelAction("Cancel");
  return await alert.presentSheet();
}

async function promptForCredentials(message) {
  while (true) {
    const alert = new Alert();
    alert.title = "Codex credentials";
    alert.message =
      message ||
      "Paste ~/.codex/auth.json. Only access_token and account_id will be saved to Keychain.";
    alert.addTextField("auth.json or access token");
    alert.addTextField("account_id (only needed with a raw token)");
    alert.addAction("Save");
    alert.addCancelAction("Cancel");

    const action = await alert.presentAlert();
    if (action === -1) return null;

    try {
      const credentials = parseCredentials(alert.textFieldValue(0), alert.textFieldValue(1));
      Keychain.set(CREDENTIALS_KEY, JSON.stringify(credentials));
      return credentials;
    } catch (error) {
      const invalidAlert = new Alert();
      invalidAlert.title = "Invalid credentials";
      invalidAlert.message = error.message;
      invalidAlert.addAction("Try again");
      await invalidAlert.presentAlert();
    }
  }
}

function parseCredentials(input, fallbackAccountId) {
  const value = input.trim();
  if (!value) throw new Error("auth.json or an access token is required.");

  let accessToken;
  let accountId = fallbackAccountId.trim();

  if (value.startsWith("{")) {
    let auth;
    try {
      auth = JSON.parse(value);
    } catch (_) {
      throw new Error("The pasted auth.json is not valid JSON.");
    }

    const tokens = auth.tokens || auth;
    accessToken = tokens.access_token || tokens.accessToken;
    accountId = tokens.account_id || tokens.accountId || accountId;
  } else {
    accessToken = value;
  }

  if (!accessToken) {
    throw new Error("The pasted credentials do not contain access_token.");
  }

  return { accessToken, accountId: accountId || null };
}

async function fetchUsage(credentials) {
  const request = new Request(USAGE_URL);
  request.timeoutInterval = 30;
  request.headers = {
    Authorization: `Bearer ${credentials.accessToken}`,
    "OpenAI-Beta": "codex-1",
    originator: "Codex Desktop",
  };
  if (credentials.accountId) {
    request.headers["ChatGPT-Account-ID"] = credentials.accountId;
  }

  let payload;
  try {
    payload = await request.loadJSON();
  } catch (cause) {
    const statusCode = request.response ? request.response.statusCode : 0;
    if (statusCode) {
      const error = new Error(`Codex API returned HTTP ${statusCode}.`);
      error.statusCode = statusCode;
      throw error;
    }
    throw cause;
  }

  const statusCode = request.response ? request.response.statusCode : 0;
  if (statusCode < 200 || statusCode >= 300) {
    const error = new Error(`Codex API returned HTTP ${statusCode}.`);
    error.statusCode = statusCode;
    throw error;
  }

  const rateLimit = payload.rate_limit || {};
  const primaryWindow = rateLimit.primary_window || {};
  if (typeof primaryWindow.used_percent !== "number") {
    throw new Error("Codex API response does not contain usage data.");
  }

  const credits = payload.rate_limit_reset_credits || {};
  const availableCount = Number(credits.available_count || 0);

  return {
    remainingPercent: clamp(100 - primaryWindow.used_percent, 0, 100),
    resetAt: Number(primaryWindow.reset_at || 0),
    availableResets: Number.isFinite(availableCount) ? Math.max(0, availableCount) : 0,
  };
}

function createUsageWidget(usage) {
  const widget = createBaseWidget();
  widget.setPadding(14, 14, 12, 14);

  const header = widget.addStack();
  header.centerAlignContent();
  addText(header, "CODEX", Font.semiboldSystemFont(12), COLORS.primary);
  header.addSpacer();
  addText(
    header,
    formatDate(Date.now() / 1000, "HH:mm"),
    Font.mediumSystemFont(10),
    COLORS.secondary,
  );

  widget.addSpacer(10);

  const metrics = widget.addStack();
  metrics.centerAlignContent();

  const usageColumn = metrics.addStack();
  usageColumn.layoutVertically();
  addText(
    usageColumn,
    `${formatNumber(usage.remainingPercent)}%`,
    Font.boldSystemFont(32),
    COLORS.usage,
  );
  addText(usageColumn, "1w remaining", Font.mediumSystemFont(10), COLORS.secondary);

  metrics.addSpacer();

  const resetColumn = metrics.addStack();
  resetColumn.layoutVertically();
  const resetCount = addText(
    resetColumn,
    formatNumber(usage.availableResets),
    Font.boldSystemFont(26),
    COLORS.resets,
  );
  resetCount.rightAlignText();
  const resetLabel = addText(resetColumn, "resets", Font.mediumSystemFont(10), COLORS.secondary);
  resetLabel.rightAlignText();

  widget.addSpacer();

  const footer = widget.addStack();
  footer.backgroundColor = COLORS.secondaryBackground;
  footer.cornerRadius = 6;
  footer.setPadding(5, 7, 5, 7);
  addText(footer, "Usage resets", Font.mediumSystemFont(10), COLORS.secondary);
  footer.addSpacer();
  addText(
    footer,
    formatDate(usage.resetAt, "MM-dd HH:mm"),
    Font.semiboldSystemFont(10),
    COLORS.primary,
  );

  widget.refreshAfterDate = new Date(Date.now() + REFRESH_INTERVAL_MS);
  return widget;
}

function createErrorWidget(title, message) {
  const widget = createBaseWidget();
  widget.setPadding(14, 14, 14, 14);

  addText(widget, "CODEX", Font.semiboldSystemFont(12), COLORS.primary);
  widget.addSpacer();
  addText(widget, title, Font.boldSystemFont(18), COLORS.error);
  widget.addSpacer(4);
  const detail = addText(widget, message, Font.mediumSystemFont(11), COLORS.secondary);
  detail.lineLimit = 3;
  widget.addSpacer();

  widget.refreshAfterDate = new Date(Date.now() + REFRESH_INTERVAL_MS);
  return widget;
}

function createBaseWidget() {
  const widget = new ListWidget();
  widget.backgroundColor = COLORS.background;
  return widget;
}

function addText(container, value, font, color) {
  const text = container.addText(value);
  text.font = font;
  text.textColor = color;
  text.lineLimit = 1;
  text.minimumScaleFactor = 0.7;
  return text;
}

function formatDate(timestamp, format) {
  if (!Number.isFinite(timestamp) || timestamp <= 0) return "--";

  const formatter = new DateFormatter();
  formatter.locale = "en_US_POSIX";
  formatter.timeZone = TIME_ZONE;
  formatter.dateFormat = format;
  return formatter.string(new Date(timestamp * 1000));
}

function formatNumber(value) {
  return Number.isInteger(value) ? String(value) : value.toFixed(1);
}

function clamp(value, minimum, maximum) {
  return Math.min(Math.max(value, minimum), maximum);
}

function isAuthenticationError(error) {
  return error.statusCode === 401 || error.statusCode === 403;
}

function errorContent(error) {
  if (isAuthenticationError(error)) {
    return ["Authentication expired", "Run the script to update auth.json"];
  }
  if (error.statusCode === 429) {
    return ["Too many requests", "Codex API rate limit reached"];
  }
  return ["Unable to load usage", error.message || "Unknown error"];
}

async function showWidget(widget) {
  Script.setWidget(widget);
  if (config.runsInApp) await widget.presentSmall();
}

await run();
Script.complete();
