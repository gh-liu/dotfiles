// https://docs.scriptable.app/
//
// Setup:
// 1. Enable device code login in ChatGPT security settings.
// 2. Run this script in Scriptable and sign in to ChatGPT when prompted.
// 3. Add a small Scriptable widget and select this script.

const USAGE_URL = "https://chatgpt.com/backend-api/wham/usage";
const AUTH_BASE_URL = "https://auth.openai.com";
const CLIENT_ID = "app_EMoamEEZ73f0CkXaXp7hrann";
const CREDENTIALS_KEY = "com.liu.scriptable.codex.credentials";
const TIME_ZONE = "Asia/Shanghai";
const REFRESH_INTERVAL_MS = 15 * 60 * 1000;
const DEVICE_AUTH_TIMEOUT_MS = 15 * 60 * 1000;

const COLORS = {
  background: new Color("111827"),
  secondaryBackground: new Color("1f2937"),
  primary: new Color("f9fafb"),
  secondary: new Color("9ca3af"),
  usage: new Color("34d399"),
  resets: new Color("60a5fa"),
  error: new Color("f87171"),
};

class CodexUsageApp {
  constructor(auth, usageClient, widget) {
    this.auth = auth;
    this.usageClient = usageClient;
    this.widget = widget;
  }

  async run() {
    let credentials = this.auth.loadCredentials();

    if (config.runsInApp) {
      if (credentials) {
        const action = await this.chooseAction();
        if (action === -1) return;
        if (action === 1) {
          credentials = await this.auth.signInWithDeviceCode();
          if (!credentials) return;
        }
      } else {
        credentials = await this.auth.signInWithDeviceCode();
        if (!credentials) return;
      }
    }

    if (!credentials) {
      await this.widget.show(
        this.widget.createError("Setup required", "Run the script to sign in to ChatGPT"),
      );
      return;
    }

    try {
      credentials = await this.auth.refreshCredentialsIfNeeded(credentials);
      await this.showUsage(credentials);
    } catch (error) {
      if (this.isAuthenticationError(error) && credentials.refreshToken) {
        try {
          credentials = await this.auth.refreshCredentials(credentials);
          await this.showUsage(credentials);
          return;
        } catch (refreshError) {
          error = refreshError;
        }
      }

      if (config.runsInApp && this.isAuthenticationError(error)) {
        const updatedCredentials = await this.auth.signInWithDeviceCode();
        if (!updatedCredentials) return;
        try {
          await this.showUsage(updatedCredentials);
          return;
        } catch (retryError) {
          error = retryError;
        }
      }

      await this.widget.show(this.widget.createError(...this.errorContent(error)));
    }
  }

  async showUsage(credentials) {
    const usage = await this.usageClient.fetch(credentials);
    await this.widget.show(this.widget.createUsage(usage));
  }

  async chooseAction() {
    const alert = new Alert();
    alert.title = "Codex Usage";
    alert.addAction("Preview widget");
    alert.addAction("Sign in again");
    alert.addCancelAction("Cancel");
    return await alert.presentSheet();
  }

  isAuthenticationError(error) {
    return error.statusCode === 401 || error.statusCode === 403;
  }

  errorContent(error) {
    if (this.isAuthenticationError(error)) {
      return ["Authentication expired", "Run the script to sign in again"];
    }
    if (error.statusCode === 429) {
      return ["Too many requests", "Codex API rate limit reached"];
    }
    return ["Unable to load usage", error.message || "Unknown error"];
  }
}

class CodexAuth {
  constructor(baseUrl, clientId, credentialsKey) {
    this.baseUrl = baseUrl;
    this.clientId = clientId;
    this.credentialsKey = credentialsKey;
  }

  loadCredentials() {
    if (!Keychain.contains(this.credentialsKey)) return null;

    try {
      const credentials = JSON.parse(Keychain.get(this.credentialsKey));
      if (!credentials.accessToken) return null;
      return credentials;
    } catch (_) {
      return null;
    }
  }

  async signInWithDeviceCode() {
    try {
      const deviceCode = await this.requestDeviceCode();
      Pasteboard.copyString(deviceCode.userCode);

      const alert = new Alert();
      alert.title = "Sign in to Codex";
      alert.message =
        `Code ${deviceCode.userCode} was copied. Open the sign-in page, paste the code, ` +
        "finish signing in, then close the browser to return to Scriptable.";
      alert.addAction("Open sign-in page");
      alert.addCancelAction("Cancel");
      if ((await alert.presentAlert()) === -1) return null;

      await Safari.openInApp(deviceCode.verificationUrl, false);
      const codeExchange = await this.pollForAuthorization(deviceCode);
      const tokens = await this.exchangeAuthorizationCode(codeExchange);
      const credentials = this.credentialsFromTokens(tokens);
      this.saveCredentials(credentials);
      return credentials;
    } catch (error) {
      const alert = new Alert();
      alert.title = "Unable to sign in";
      alert.message = error.message || "Unknown authentication error";
      alert.addAction("OK");
      await alert.presentAlert();
      return null;
    }
  }

  async requestDeviceCode() {
    const response = await this.post(
      `${this.baseUrl}/api/accounts/deviceauth/usercode`,
      { client_id: this.clientId },
      "application/json",
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      if (response.statusCode === 403 || response.statusCode === 404) {
        throw new Error("Enable device code login in ChatGPT security settings and try again.");
      }
      throw new Error(`Device code request returned HTTP ${response.statusCode}.`);
    }

    const payload = response.payload || {};
    const userCode = payload.user_code || payload.usercode;
    if (!payload.device_auth_id || !userCode) {
      throw new Error("Device code response is incomplete.");
    }

    return {
      deviceAuthId: payload.device_auth_id,
      userCode,
      interval: Math.max(Number(payload.interval) || 5, 1),
      verificationUrl: `${this.baseUrl}/codex/device`,
    };
  }

  async pollForAuthorization(deviceCode) {
    const deadline = Date.now() + DEVICE_AUTH_TIMEOUT_MS;
    while (Date.now() < deadline) {
      const response = await this.post(
        `${this.baseUrl}/api/accounts/deviceauth/token`,
        {
          device_auth_id: deviceCode.deviceAuthId,
          user_code: deviceCode.userCode,
        },
        "application/json",
      );
      if (response.statusCode >= 200 && response.statusCode < 300) {
        const payload = response.payload || {};
        if (!payload.authorization_code || !payload.code_verifier) {
          throw new Error("Device authorization response is incomplete.");
        }
        return payload;
      }
      if (response.statusCode !== 403 && response.statusCode !== 404) {
        throw new Error(`Device authorization returned HTTP ${response.statusCode}.`);
      }
      await this.sleep(deviceCode.interval);
    }
    throw new Error("Device authorization timed out after 15 minutes.");
  }

  async exchangeAuthorizationCode(codeExchange) {
    const redirectUri = `${this.baseUrl}/deviceauth/callback`;
    const body = [
      ["grant_type", "authorization_code"],
      ["code", codeExchange.authorization_code],
      ["redirect_uri", redirectUri],
      ["client_id", this.clientId],
      ["code_verifier", codeExchange.code_verifier],
    ]
      .map(([key, value]) => `${key}=${encodeURIComponent(value)}`)
      .join("&");
    const response = await this.post(
      `${this.baseUrl}/oauth/token`,
      body,
      "application/x-www-form-urlencoded",
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw new Error(`Token exchange returned HTTP ${response.statusCode}.`);
    }
    return response.payload || {};
  }

  credentialsFromTokens(tokens) {
    if (!tokens.access_token || !tokens.refresh_token || !tokens.id_token) {
      throw new Error("Token response is incomplete.");
    }
    const idToken = this.decodeJwtPayload(tokens.id_token);
    const auth = idToken["https://api.openai.com/auth"] || {};
    return {
      accessToken: tokens.access_token,
      refreshToken: tokens.refresh_token,
      accountId: auth.chatgpt_account_id || null,
    };
  }

  saveCredentials(credentials) {
    Keychain.set(this.credentialsKey, JSON.stringify(credentials));
  }

  async refreshCredentialsIfNeeded(credentials) {
    if (!credentials.refreshToken) return credentials;
    const payload = this.decodeJwtPayload(credentials.accessToken);
    if (!payload.exp || payload.exp * 1000 > Date.now() + 60 * 1000) return credentials;
    return await this.refreshCredentials(credentials);
  }

  async refreshCredentials(credentials) {
    const response = await this.post(
      `${this.baseUrl}/oauth/token`,
      {
        client_id: this.clientId,
        grant_type: "refresh_token",
        refresh_token: credentials.refreshToken,
      },
      "application/json",
    );
    if (response.statusCode < 200 || response.statusCode >= 300) {
      const error = new Error(`Token refresh returned HTTP ${response.statusCode}.`);
      error.statusCode = response.statusCode === 400 ? 401 : response.statusCode;
      throw error;
    }

    const tokens = response.payload || {};
    if (!tokens.access_token) {
      throw new Error("Token refresh response does not contain access_token.");
    }
    const updated = {
      accessToken: tokens.access_token,
      refreshToken: tokens.refresh_token || credentials.refreshToken,
      accountId: credentials.accountId,
    };
    if (tokens.id_token) {
      const auth = this.decodeJwtPayload(tokens.id_token)["https://api.openai.com/auth"] || {};
      updated.accountId = auth.chatgpt_account_id || updated.accountId;
    }
    this.saveCredentials(updated);
    return updated;
  }

  decodeJwtPayload(token) {
    try {
      let encoded = token.split(".")[1].replace(/-/g, "+").replace(/_/g, "/");
      encoded += "=".repeat((4 - (encoded.length % 4)) % 4);
      return JSON.parse(Data.fromBase64String(encoded).toRawString());
    } catch (_) {
      throw new Error("OpenAI returned an invalid token.");
    }
  }

  async post(url, body, contentType) {
    const request = new Request(url);
    request.method = "POST";
    request.timeoutInterval = 30;
    request.headers = { "Content-Type": contentType };
    request.body = typeof body === "string" ? body : JSON.stringify(body);

    const text = await request.loadString();
    let payload = null;
    if (text) {
      try {
        payload = JSON.parse(text);
      } catch (_) { }
    }
    return {
      statusCode: request.response ? request.response.statusCode : 0,
      payload,
    };
  }

  sleep(seconds) {
    return new Promise((resolve) => Timer.schedule(seconds, false, resolve));
  }
}

class CodexUsageClient {
  constructor(url) {
    this.url = url;
  }

  async fetch(credentials) {
    const request = new Request(this.url);
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
      remainingPercent: Math.min(Math.max(100 - primaryWindow.used_percent, 0), 100),
      resetAt: Number(primaryWindow.reset_at || 0),
      availableResets: Number.isFinite(availableCount) ? Math.max(0, availableCount) : 0,
    };
  }
}

class CodexUsageWidget {
  createUsage(usage) {
    const widget = this.createBase();
    widget.setPadding(14, 14, 12, 14);

    const header = widget.addStack();
    header.centerAlignContent();
    this.addText(header, "CODEX", Font.semiboldSystemFont(12), COLORS.primary);
    header.addSpacer();
    this.addText(
      header,
      this.formatDate(Date.now() / 1000, "HH:mm"),
      Font.mediumSystemFont(10),
      COLORS.secondary,
    );

    widget.addSpacer(10);

    const metrics = widget.addStack();
    metrics.centerAlignContent();

    const usageColumn = metrics.addStack();
    usageColumn.layoutVertically();
    this.addText(
      usageColumn,
      `${this.formatNumber(usage.remainingPercent)}%`,
      Font.boldSystemFont(32),
      COLORS.usage,
    );
    this.addText(usageColumn, "1w remaining", Font.mediumSystemFont(10), COLORS.secondary);

    metrics.addSpacer();

    const resetColumn = metrics.addStack();
    resetColumn.layoutVertically();
    const resetCount = this.addText(
      resetColumn,
      this.formatNumber(usage.availableResets),
      Font.boldSystemFont(26),
      COLORS.resets,
    );
    resetCount.rightAlignText();
    const resetLabel = this.addText(
      resetColumn,
      "resets",
      Font.mediumSystemFont(10),
      COLORS.secondary,
    );
    resetLabel.rightAlignText();

    widget.addSpacer();

    const footer = widget.addStack();
    footer.backgroundColor = COLORS.secondaryBackground;
    footer.cornerRadius = 6;
    footer.setPadding(5, 7, 5, 7);
    this.addText(footer, "Usage resets", Font.mediumSystemFont(10), COLORS.secondary);
    footer.addSpacer();
    this.addText(
      footer,
      this.formatDate(usage.resetAt, "MM-dd HH:mm"),
      Font.semiboldSystemFont(10),
      COLORS.primary,
    );

    widget.refreshAfterDate = new Date(Date.now() + REFRESH_INTERVAL_MS);
    return widget;
  }

  createError(title, message) {
    const widget = this.createBase();
    widget.setPadding(14, 14, 14, 14);

    this.addText(widget, "CODEX", Font.semiboldSystemFont(12), COLORS.primary);
    widget.addSpacer();
    this.addText(widget, title, Font.boldSystemFont(18), COLORS.error);
    widget.addSpacer(4);
    const detail = this.addText(widget, message, Font.mediumSystemFont(11), COLORS.secondary);
    detail.lineLimit = 3;
    widget.addSpacer();

    widget.refreshAfterDate = new Date(Date.now() + REFRESH_INTERVAL_MS);
    return widget;
  }

  createBase() {
    const widget = new ListWidget();
    widget.backgroundColor = COLORS.background;
    return widget;
  }

  addText(container, value, font, color) {
    const text = container.addText(value);
    text.font = font;
    text.textColor = color;
    text.lineLimit = 1;
    text.minimumScaleFactor = 0.7;
    return text;
  }

  formatDate(timestamp, format) {
    if (!Number.isFinite(timestamp) || timestamp <= 0) return "--";

    const formatter = new DateFormatter();
    formatter.locale = "en_US_POSIX";
    formatter.timeZone = TIME_ZONE;
    formatter.dateFormat = format;
    return formatter.string(new Date(timestamp * 1000));
  }

  formatNumber(value) {
    return Number.isInteger(value) ? String(value) : value.toFixed(1);
  }

  async show(widget) {
    Script.setWidget(widget);
    if (config.runsInApp) await widget.presentSmall();
  }
}

const auth = new CodexAuth(AUTH_BASE_URL, CLIENT_ID, CREDENTIALS_KEY);
const usageClient = new CodexUsageClient(USAGE_URL);
const widget = new CodexUsageWidget();
const app = new CodexUsageApp(auth, usageClient, widget);

await app.run();
Script.complete();
