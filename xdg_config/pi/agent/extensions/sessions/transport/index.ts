export type ActiveSession = {
  id: string;
  name?: string;
  cwd: string;
  model: string;
  pid: number;
  startedAt: number;
  lastActivity: number;
  status?: string;
};

export type ActiveSessionRegistration = Omit<ActiveSession, "id">;

export type ActiveSessionMessage = {
  id: string;
  timestamp: number;
  replyTo?: string;
  expectsReply?: boolean;
  content: {
    text: string;
  };
};

export type ActiveSessionSendOptions = {
  text: string;
  replyTo?: string;
  expectsReply?: boolean;
  messageId?: string;
};

export type ActiveSessionSendResult = {
  id: string;
  delivered: boolean;
  reason?: string;
};

export type ActiveSessionMessageHandler = (from: ActiveSession, message: ActiveSessionMessage) => void;
export type ActiveSessionDisconnectedHandler = (error: Error) => void;

/** The smallest communication surface required by the sessions tools. */
export interface ActiveSessionTransport {
  readonly sessionId: string | null;
  connect(registration: ActiveSessionRegistration, sessionId?: string): Promise<void>;
  listSessions(): Promise<ActiveSession[]>;
  send(to: string, options: ActiveSessionSendOptions): Promise<ActiveSessionSendResult>;
  cancel(messageId: string): Promise<ActiveSessionSendResult>;
  cancelAsk(messageId: string): void;
  disconnect(): Promise<void>;
  onMessage(handler: ActiveSessionMessageHandler): () => void;
  onDisconnected(handler: ActiveSessionDisconnectedHandler): () => void;
}

export type ActiveSessionTransportFactory = () => ActiveSessionTransport;
