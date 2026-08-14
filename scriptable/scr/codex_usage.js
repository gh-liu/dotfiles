// https://docs.scriptable.app/
//
// Setup:
// 1. Enable device code login in ChatGPT security settings.
// 2. Run this script in Scriptable and sign in to ChatGPT when prompted.
// 3. Enable notifications for Scriptable in iOS Settings.
// 4. Add a small Scriptable widget and select this script.

const SETTINGS = Object.freeze({
  usageUrl: "https://chatgpt.com/backend-api/wham/usage",
  authBaseUrl: "https://auth.openai.com",
  clientId: "app_EMoamEEZ73f0CkXaXp7hrann",
  credentialsKey: "com.liu.scriptable.codex.credentials",
  notificationStateKey: "com.liu.scriptable.codex.usage-boundary",
  resetCountStateKey: "com.liu.scriptable.codex.reset-count",
  timeZone: "Asia/Shanghai",
  requestTimeoutSeconds: 30,
  tokenRefreshLeewayMs: 60 * 1000,
  refreshIntervalMs: 15 * 60 * 1000,
  deviceAuthTimeoutMs: 15 * 60 * 1000,
  progressBarWidth: 120,
  progressBarHeight: 6,
});

const RUNTIME = Object.freeze({
  runsInApp: config.runsInApp,
  runsInWidget: config.runsInWidget,
});

const dynamicColor = (light, dark) => Color.dynamic(new Color(light), new Color(dark));

const COLORS = Object.freeze({
  background: dynamicColor("f9fafb", "111827"),
  secondaryBackground: dynamicColor("e5e7eb", "1f2937"),
  primary: dynamicColor("111827", "f9fafb"),
  secondary: dynamicColor("6b7280", "9ca3af"),
  usage: dynamicColor("059669", "34d399"),
  resets: dynamicColor("2563eb", "60a5fa"),
  error: dynamicColor("dc2626", "f87171"),
});

// Infrastructure
class HttpClient {
  constructor(timeoutInterval) {
    this.timeoutInterval = timeoutInterval;
  }

  getJson(url, headers = {}) {
    return this.requestJson("GET", url, headers);
  }

  postJson(url, body, contentType = "application/json") {
    return this.requestJson("POST", url, { "Content-Type": contentType }, body);
  }

  async requestJson(method, url, headers, body) {
    const request = new Request(url);
    request.method = method;
    request.timeoutInterval = this.timeoutInterval;
    request.headers = headers;
    if (body !== undefined) {
      request.body = typeof body === "string" ? body : JSON.stringify(body);
    }

    const text = await request.loadString();
    let payload = null;
    if (text) {
      try {
        payload = JSON.parse(text);
      } catch (_) {}
    }

    const statusCode = request.response ? request.response.statusCode : 0;
    return {
      ok: statusCode >= 200 && statusCode < 300,
      statusCode,
      payload,
    };
  }
}

// Application workflow
class CodexUsageApp {
  constructor(auth, usageClient, notifier, view, runtime) {
    this.auth = auth;
    this.usageClient = usageClient;
    this.notifier = notifier;
    this.view = view;
    this.runtime = runtime;
  }

  async run() {
    if (!this.runtime.runsInApp && !this.runtime.runsInWidget) return;

    let credentials = this.auth.loadCredentials();

    if (this.runtime.runsInApp) {
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
      await this.view.show(
        this.view.createError("Setup required", "Run the script to sign in to ChatGPT"),
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

      if (this.runtime.runsInApp && this.isAuthenticationError(error)) {
        const updatedCredentials = await this.auth.signInWithDeviceCode();
        if (!updatedCredentials) return;
        try {
          await this.showUsage(updatedCredentials);
          return;
        } catch (retryError) {
          error = retryError;
        }
      }

      await this.view.show(this.view.createError(...this.errorContent(error)));
    }
  }

  async showUsage(credentials) {
    const usage = await this.usageClient.fetch(credentials);
    try {
      await this.notifier.notifyIfNeeded(usage);
    } catch (error) {
      console.warn(`Unable to schedule Codex usage notification: ${error}`);
    }
    await this.view.show(this.view.createUsage(usage));
  }

  async chooseAction() {
    const alert = new Alert();
    alert.title = "Codex Usage";
    alert.addAction("Preview widget");
    alert.addAction("Sign in again");
    alert.addCancelAction("Cancel");
    return alert.presentSheet();
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

// Authentication and credential lifecycle
class CodexAuth {
  constructor(http, settings) {
    this.http = http;
    this.settings = settings;
  }

  loadCredentials() {
    if (!Keychain.contains(this.settings.credentialsKey)) return null;

    try {
      const credentials = JSON.parse(Keychain.get(this.settings.credentialsKey));
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
    const response = await this.http.postJson(this.authUrl("/api/accounts/deviceauth/usercode"), {
      client_id: this.settings.clientId,
    });
    if (!response.ok) {
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
      verificationUrl: this.authUrl("/codex/device"),
    };
  }

  async pollForAuthorization(deviceCode) {
    const deadline = Date.now() + this.settings.deviceAuthTimeoutMs;
    while (Date.now() < deadline) {
      const response = await this.http.postJson(this.authUrl("/api/accounts/deviceauth/token"), {
        device_auth_id: deviceCode.deviceAuthId,
        user_code: deviceCode.userCode,
      });
      if (response.ok) {
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
    const timeoutMinutes = this.settings.deviceAuthTimeoutMs / (60 * 1000);
    throw new Error(`Device authorization timed out after ${timeoutMinutes} minutes.`);
  }

  async exchangeAuthorizationCode(codeExchange) {
    const redirectUri = this.authUrl("/deviceauth/callback");
    const body = [
      ["grant_type", "authorization_code"],
      ["code", codeExchange.authorization_code],
      ["redirect_uri", redirectUri],
      ["client_id", this.settings.clientId],
      ["code_verifier", codeExchange.code_verifier],
    ]
      .map(([key, value]) => `${key}=${encodeURIComponent(value)}`)
      .join("&");
    const response = await this.http.postJson(
      this.authUrl("/oauth/token"),
      body,
      "application/x-www-form-urlencoded",
    );
    if (!response.ok) {
      throw new Error(`Token exchange returned HTTP ${response.statusCode}.`);
    }
    return response.payload || {};
  }

  credentialsFromTokens(tokens) {
    if (!tokens.access_token || !tokens.refresh_token || !tokens.id_token) {
      throw new Error("Token response is incomplete.");
    }
    return {
      accessToken: tokens.access_token,
      refreshToken: tokens.refresh_token,
      accountId: this.accountIdFromIdToken(tokens.id_token),
    };
  }

  saveCredentials(credentials) {
    Keychain.set(this.settings.credentialsKey, JSON.stringify(credentials));
  }

  async refreshCredentialsIfNeeded(credentials) {
    if (!credentials.refreshToken) return credentials;
    const payload = this.decodeJwtPayload(credentials.accessToken);
    if (!payload.exp || payload.exp * 1000 > Date.now() + this.settings.tokenRefreshLeewayMs) {
      return credentials;
    }
    return this.refreshCredentials(credentials);
  }

  async refreshCredentials(credentials) {
    const response = await this.http.postJson(this.authUrl("/oauth/token"), {
      client_id: this.settings.clientId,
      grant_type: "refresh_token",
      refresh_token: credentials.refreshToken,
    });
    if (!response.ok) {
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
      updated.accountId = this.accountIdFromIdToken(tokens.id_token) || updated.accountId;
    }
    this.saveCredentials(updated);
    return updated;
  }

  accountIdFromIdToken(idToken) {
    const payload = this.decodeJwtPayload(idToken);
    const auth = payload["https://api.openai.com/auth"] || {};
    return auth.chatgpt_account_id || null;
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

  sleep(seconds) {
    return new Promise((resolve) => Timer.schedule(seconds, false, resolve));
  }

  authUrl(path) {
    return `${this.settings.authBaseUrl}${path}`;
  }
}

// Codex usage API
class CodexUsageClient {
  constructor(http, settings) {
    this.http = http;
    this.settings = settings;
  }

  async fetch(credentials) {
    const headers = {
      Authorization: `Bearer ${credentials.accessToken}`,
      "OpenAI-Beta": "codex-1",
      originator: "Codex Desktop",
    };
    if (credentials.accountId) {
      headers["ChatGPT-Account-ID"] = credentials.accountId;
    }

    const response = await this.http.getJson(this.settings.usageUrl, headers);
    if (!response.ok) {
      const error = new Error(`Codex API returned HTTP ${response.statusCode}.`);
      error.statusCode = response.statusCode;
      throw error;
    }

    const payload = response.payload || {};
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

// Usage notifications
class CodexUsageNotifier {
  constructor(settings) {
    this.settings = settings;
  }

  async notifyIfNeeded(usage) {
    await this.notifyUsageBoundaryIfNeeded(usage.remainingPercent);
    await this.notifyResetIncreaseIfNeeded(usage.availableResets);
  }

  async notifyUsageBoundaryIfNeeded(remainingPercent) {
    const boundary = this.boundaryFor(remainingPercent);
    if (boundary === null) {
      if (Keychain.contains(this.settings.notificationStateKey)) {
        Keychain.remove(this.settings.notificationStateKey);
      }
      return;
    }

    if (this.loadLastBoundary() === boundary) return;

    const body =
      boundary === 0
        ? "Your weekly Codex usage has been exhausted."
        : "Your weekly Codex usage has reset and is fully available.";
    await this.scheduleNotification(
      `Codex weekly usage: ${boundary}%`,
      body,
      "codex-weekly-usage",
    );

    Keychain.set(this.settings.notificationStateKey, String(boundary));
  }

  async notifyResetIncreaseIfNeeded(availableResets) {
    const previousCount = this.loadLastResetCount();
    if (previousCount === null) {
      Keychain.set(this.settings.resetCountStateKey, String(availableResets));
      return;
    }

    if (availableResets > previousCount) {
      await this.scheduleNotification(
        `Codex resets: ${availableResets}`,
        `Available reset credits increased from ${previousCount} to ${availableResets}.`,
        "codex-reset-credits",
      );
    }

    if (availableResets !== previousCount) {
      Keychain.set(this.settings.resetCountStateKey, String(availableResets));
    }
  }

  boundaryFor(remainingPercent) {
    if (remainingPercent === 0) return 0;
    if (remainingPercent === 100) return 100;
    return null;
  }

  loadLastBoundary() {
    if (!Keychain.contains(this.settings.notificationStateKey)) return null;
    try {
      const boundary = Number(Keychain.get(this.settings.notificationStateKey));
      return boundary === 0 || boundary === 100 ? boundary : null;
    } catch (_) {
      return null;
    }
  }

  loadLastResetCount() {
    if (!Keychain.contains(this.settings.resetCountStateKey)) return null;
    try {
      const count = Number(Keychain.get(this.settings.resetCountStateKey));
      return Number.isFinite(count) && count >= 0 ? count : null;
    } catch (_) {
      return null;
    }
  }

  async scheduleNotification(title, body, threadIdentifier) {
    const notification = new Notification();
    notification.title = title;
    notification.body = body;
    notification.sound = "default";
    notification.threadIdentifier = threadIdentifier;
    await notification.schedule();
  }
}

// Widget presentation
class CodexUsageView {
  constructor(settings, colors, runtime) {
    this.settings = settings;
    this.colors = colors;
    this.runtime = runtime;
  }

  createUsage(usage) {
    const widget = this.createBase();
    widget.setPadding(14, 14, 12, 14);

    const header = widget.addStack();
    header.centerAlignContent();
    this.addText(header, "CODEX", Font.semiboldSystemFont(12), this.colors.primary);
    header.addSpacer();
    this.addText(
      header,
      this.formatDate(Date.now() / 1000, "HH:mm"),
      Font.mediumSystemFont(10),
      this.colors.secondary,
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
      this.colors.usage,
    );
    this.addText(usageColumn, "1w remaining", Font.mediumSystemFont(10), this.colors.secondary);

    metrics.addSpacer();

    const resetColumn = metrics.addStack();
    resetColumn.layoutVertically();
    const resetCount = this.addText(
      resetColumn,
      this.formatNumber(usage.availableResets),
      Font.boldSystemFont(26),
      this.colors.resets,
    );
    resetCount.rightAlignText();
    const resetLabel = this.addText(
      resetColumn,
      "resets",
      Font.mediumSystemFont(10),
      this.colors.secondary,
    );
    resetLabel.rightAlignText();

    widget.addSpacer(8);
    this.addProgressBar(widget, usage.remainingPercent);
    widget.addSpacer();

    const footer = widget.addStack();
    footer.backgroundColor = this.colors.secondaryBackground;
    footer.cornerRadius = 6;
    footer.setPadding(5, 7, 5, 7);
    this.addText(footer, "Usage resets", Font.mediumSystemFont(10), this.colors.secondary);
    footer.addSpacer();
    this.addText(
      footer,
      this.formatDate(usage.resetAt, "MM-dd HH:mm"),
      Font.semiboldSystemFont(10),
      this.colors.primary,
    );

    widget.refreshAfterDate = new Date(Date.now() + this.settings.refreshIntervalMs);
    return widget;
  }

  addProgressBar(container, percent) {
    const width = this.settings.progressBarWidth;
    const height = this.settings.progressBarHeight;
    const progress = Math.min(Math.max(percent, 0), 100);

    const track = container.addStack();
    track.size = new Size(width, height);
    track.backgroundColor = this.colors.secondaryBackground;
    track.cornerRadius = height / 2;

    if (progress > 0) {
      const fill = track.addStack();
      fill.size = new Size(Math.max((width * progress) / 100, height), height);
      fill.backgroundColor = this.colors.usage;
      fill.cornerRadius = height / 2;
    }
    track.addSpacer();
  }

  createError(title, message) {
    const widget = this.createBase();
    widget.setPadding(14, 14, 14, 14);

    this.addText(widget, "CODEX", Font.semiboldSystemFont(12), this.colors.primary);
    widget.addSpacer();
    this.addText(widget, title, Font.boldSystemFont(18), this.colors.error);
    widget.addSpacer(4);
    const detail = this.addText(widget, message, Font.mediumSystemFont(11), this.colors.secondary);
    detail.lineLimit = 3;
    widget.addSpacer();

    widget.refreshAfterDate = new Date(Date.now() + this.settings.refreshIntervalMs);
    return widget;
  }

  createBase() {
    const widget = new ListWidget();
    widget.backgroundColor = this.colors.background;
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
    formatter.timeZone = this.settings.timeZone;
    formatter.dateFormat = format;
    return formatter.string(new Date(timestamp * 1000));
  }

  formatNumber(value) {
    return Number.isInteger(value) ? String(value) : value.toFixed(1);
  }

  async show(widget) {
    if (this.runtime.runsInWidget) {
      Script.setWidget(widget);
    } else if (this.runtime.runsInApp) {
      await widget.presentSmall();
    }
  }
}

// Composition root
const http = new HttpClient(SETTINGS.requestTimeoutSeconds);
const auth = new CodexAuth(http, SETTINGS);
const usageClient = new CodexUsageClient(http, SETTINGS);
const notifier = new CodexUsageNotifier(SETTINGS);
const view = new CodexUsageView(SETTINGS, COLORS, RUNTIME);
const app = new CodexUsageApp(auth, usageClient, notifier, view, RUNTIME);

await app.run();
Script.complete();
