(() => {
  // node_modules/@tauri-apps/api/external/tslib/tslib.es6.js
  function __classPrivateFieldGet(receiver, state, kind, f) {
    if (kind === "a" && !f) throw new TypeError("Private accessor was defined without a getter");
    if (typeof state === "function" ? receiver !== state || !f : !state.has(receiver)) throw new TypeError("Cannot read private member from an object whose class did not declare it");
    return kind === "m" ? f : kind === "a" ? f.call(receiver) : f ? f.value : state.get(receiver);
  }
  function __classPrivateFieldSet(receiver, state, value, kind, f) {
    if (kind === "m") throw new TypeError("Private method is not writable");
    if (kind === "a" && !f) throw new TypeError("Private accessor was defined without a setter");
    if (typeof state === "function" ? receiver !== state || !f : !state.has(receiver)) throw new TypeError("Cannot write private member to an object whose class did not declare it");
    return kind === "a" ? f.call(receiver, value) : f ? f.value = value : state.set(receiver, value), value;
  }

  // node_modules/@tauri-apps/api/core.js
  var _Channel_onmessage;
  var _Channel_nextMessageIndex;
  var _Channel_pendingMessages;
  var _Channel_messageEndIndex;
  var _Resource_rid;
  var SERIALIZE_TO_IPC_FN = "__TAURI_TO_IPC_KEY__";
  function transformCallback(callback, once2 = false) {
    return window.__TAURI_INTERNALS__.transformCallback(callback, once2);
  }
  var Channel = class {
    constructor(onmessage) {
      _Channel_onmessage.set(this, void 0);
      _Channel_nextMessageIndex.set(this, 0);
      _Channel_pendingMessages.set(this, []);
      _Channel_messageEndIndex.set(this, void 0);
      __classPrivateFieldSet(this, _Channel_onmessage, onmessage || (() => {
      }), "f");
      this.id = transformCallback((rawMessage) => {
        const index = rawMessage.index;
        if ("end" in rawMessage) {
          if (index == __classPrivateFieldGet(this, _Channel_nextMessageIndex, "f")) {
            this.cleanupCallback();
          } else {
            __classPrivateFieldSet(this, _Channel_messageEndIndex, index, "f");
          }
          return;
        }
        const message = rawMessage.message;
        if (index == __classPrivateFieldGet(this, _Channel_nextMessageIndex, "f")) {
          __classPrivateFieldGet(this, _Channel_onmessage, "f").call(this, message);
          __classPrivateFieldSet(this, _Channel_nextMessageIndex, __classPrivateFieldGet(this, _Channel_nextMessageIndex, "f") + 1, "f");
          while (__classPrivateFieldGet(this, _Channel_nextMessageIndex, "f") in __classPrivateFieldGet(this, _Channel_pendingMessages, "f")) {
            const message2 = __classPrivateFieldGet(this, _Channel_pendingMessages, "f")[__classPrivateFieldGet(this, _Channel_nextMessageIndex, "f")];
            __classPrivateFieldGet(this, _Channel_onmessage, "f").call(this, message2);
            delete __classPrivateFieldGet(this, _Channel_pendingMessages, "f")[__classPrivateFieldGet(this, _Channel_nextMessageIndex, "f")];
            __classPrivateFieldSet(this, _Channel_nextMessageIndex, __classPrivateFieldGet(this, _Channel_nextMessageIndex, "f") + 1, "f");
          }
          if (__classPrivateFieldGet(this, _Channel_nextMessageIndex, "f") === __classPrivateFieldGet(this, _Channel_messageEndIndex, "f")) {
            this.cleanupCallback();
          }
        } else {
          __classPrivateFieldGet(this, _Channel_pendingMessages, "f")[index] = message;
        }
      });
    }
    cleanupCallback() {
      window.__TAURI_INTERNALS__.unregisterCallback(this.id);
    }
    set onmessage(handler) {
      __classPrivateFieldSet(this, _Channel_onmessage, handler, "f");
    }
    get onmessage() {
      return __classPrivateFieldGet(this, _Channel_onmessage, "f");
    }
    [(_Channel_onmessage = /* @__PURE__ */ new WeakMap(), _Channel_nextMessageIndex = /* @__PURE__ */ new WeakMap(), _Channel_pendingMessages = /* @__PURE__ */ new WeakMap(), _Channel_messageEndIndex = /* @__PURE__ */ new WeakMap(), SERIALIZE_TO_IPC_FN)]() {
      return `__CHANNEL__:${this.id}`;
    }
    toJSON() {
      return this[SERIALIZE_TO_IPC_FN]();
    }
  };
  async function invoke(cmd, args = {}, options) {
    return window.__TAURI_INTERNALS__.invoke(cmd, args, options);
  }
  var Resource = class {
    get rid() {
      return __classPrivateFieldGet(this, _Resource_rid, "f");
    }
    constructor(rid) {
      _Resource_rid.set(this, void 0);
      __classPrivateFieldSet(this, _Resource_rid, rid, "f");
    }
    /**
     * Destroys and cleans up this resource from memory.
     * **You should not call any method on this object anymore and should drop any reference to it.**
     */
    async close() {
      return invoke("plugin:resources|close", {
        rid: this.rid
      });
    }
  };
  _Resource_rid = /* @__PURE__ */ new WeakMap();

  // node_modules/@tauri-apps/plugin-dialog/dist-js/index.js
  async function open(options = {}) {
    if (typeof options === "object") {
      Object.freeze(options);
    }
    return await invoke("plugin:dialog|open", { options });
  }
  async function save(options = {}) {
    if (typeof options === "object") {
      Object.freeze(options);
    }
    return await invoke("plugin:dialog|save", { options });
  }

  // node_modules/@tauri-apps/api/path.js
  var BaseDirectory;
  (function(BaseDirectory2) {
    BaseDirectory2[BaseDirectory2["Audio"] = 1] = "Audio";
    BaseDirectory2[BaseDirectory2["Cache"] = 2] = "Cache";
    BaseDirectory2[BaseDirectory2["Config"] = 3] = "Config";
    BaseDirectory2[BaseDirectory2["Data"] = 4] = "Data";
    BaseDirectory2[BaseDirectory2["LocalData"] = 5] = "LocalData";
    BaseDirectory2[BaseDirectory2["Document"] = 6] = "Document";
    BaseDirectory2[BaseDirectory2["Download"] = 7] = "Download";
    BaseDirectory2[BaseDirectory2["Picture"] = 8] = "Picture";
    BaseDirectory2[BaseDirectory2["Public"] = 9] = "Public";
    BaseDirectory2[BaseDirectory2["Video"] = 10] = "Video";
    BaseDirectory2[BaseDirectory2["Resource"] = 11] = "Resource";
    BaseDirectory2[BaseDirectory2["Temp"] = 12] = "Temp";
    BaseDirectory2[BaseDirectory2["AppConfig"] = 13] = "AppConfig";
    BaseDirectory2[BaseDirectory2["AppData"] = 14] = "AppData";
    BaseDirectory2[BaseDirectory2["AppLocalData"] = 15] = "AppLocalData";
    BaseDirectory2[BaseDirectory2["AppCache"] = 16] = "AppCache";
    BaseDirectory2[BaseDirectory2["AppLog"] = 17] = "AppLog";
    BaseDirectory2[BaseDirectory2["Desktop"] = 18] = "Desktop";
    BaseDirectory2[BaseDirectory2["Executable"] = 19] = "Executable";
    BaseDirectory2[BaseDirectory2["Font"] = 20] = "Font";
    BaseDirectory2[BaseDirectory2["Home"] = 21] = "Home";
    BaseDirectory2[BaseDirectory2["Runtime"] = 22] = "Runtime";
    BaseDirectory2[BaseDirectory2["Template"] = 23] = "Template";
  })(BaseDirectory || (BaseDirectory = {}));

  // node_modules/@tauri-apps/plugin-fs/dist-js/index.js
  var SeekMode;
  (function(SeekMode2) {
    SeekMode2[SeekMode2["Start"] = 0] = "Start";
    SeekMode2[SeekMode2["Current"] = 1] = "Current";
    SeekMode2[SeekMode2["End"] = 2] = "End";
  })(SeekMode || (SeekMode = {}));
  async function readFile(path2, options) {
    if (path2 instanceof URL && path2.protocol !== "file:") {
      throw new TypeError("Must be a file URL.");
    }
    const arr = await invoke("plugin:fs|read_file", {
      path: path2 instanceof URL ? path2.toString() : path2,
      options
    });
    return arr instanceof ArrayBuffer ? new Uint8Array(arr) : Uint8Array.from(arr);
  }
  async function readTextFile(path2, options) {
    if (path2 instanceof URL && path2.protocol !== "file:") {
      throw new TypeError("Must be a file URL.");
    }
    const arr = await invoke("plugin:fs|read_text_file", {
      path: path2 instanceof URL ? path2.toString() : path2,
      options
    });
    const bytes = arr instanceof ArrayBuffer ? arr : Uint8Array.from(arr);
    return new TextDecoder(options?.encoding ?? "utf-8").decode(bytes);
  }
  async function writeTextFile(path2, data, options) {
    if (path2 instanceof URL && path2.protocol !== "file:") {
      throw new TypeError("Must be a file URL.");
    }
    const encoder = new TextEncoder();
    await invoke("plugin:fs|write_text_file", encoder.encode(data), {
      headers: {
        path: encodeURIComponent(path2 instanceof URL ? path2.toString() : path2),
        options: JSON.stringify(options)
      }
    });
  }

  // node_modules/@tauri-apps/api/dpi.js
  var LogicalSize = class {
    constructor(...args) {
      this.type = "Logical";
      if (args.length === 1) {
        if ("Logical" in args[0]) {
          this.width = args[0].Logical.width;
          this.height = args[0].Logical.height;
        } else {
          this.width = args[0].width;
          this.height = args[0].height;
        }
      } else {
        this.width = args[0];
        this.height = args[1];
      }
    }
    /**
     * Converts the logical size to a physical one.
     * @example
     * ```typescript
     * import { LogicalSize } from '@tauri-apps/api/dpi';
     * import { getCurrentWindow } from '@tauri-apps/api/window';
     *
     * const appWindow = getCurrentWindow();
     * const factor = await appWindow.scaleFactor();
     * const size = new LogicalSize(400, 500);
     * const physical = size.toPhysical(factor);
     * ```
     *
     * @since 2.0.0
     */
    toPhysical(scaleFactor) {
      return new PhysicalSize(this.width * scaleFactor, this.height * scaleFactor);
    }
    [SERIALIZE_TO_IPC_FN]() {
      return {
        width: this.width,
        height: this.height
      };
    }
    toJSON() {
      return this[SERIALIZE_TO_IPC_FN]();
    }
  };
  var PhysicalSize = class {
    constructor(...args) {
      this.type = "Physical";
      if (args.length === 1) {
        if ("Physical" in args[0]) {
          this.width = args[0].Physical.width;
          this.height = args[0].Physical.height;
        } else {
          this.width = args[0].width;
          this.height = args[0].height;
        }
      } else {
        this.width = args[0];
        this.height = args[1];
      }
    }
    /**
     * Converts the physical size to a logical one.
     * @example
     * ```typescript
     * import { getCurrentWindow } from '@tauri-apps/api/window';
     * const appWindow = getCurrentWindow();
     * const factor = await appWindow.scaleFactor();
     * const size = await appWindow.innerSize(); // PhysicalSize
     * const logical = size.toLogical(factor);
     * ```
     */
    toLogical(scaleFactor) {
      return new LogicalSize(this.width / scaleFactor, this.height / scaleFactor);
    }
    [SERIALIZE_TO_IPC_FN]() {
      return {
        width: this.width,
        height: this.height
      };
    }
    toJSON() {
      return this[SERIALIZE_TO_IPC_FN]();
    }
  };
  var Size = class {
    constructor(size) {
      this.size = size;
    }
    toLogical(scaleFactor) {
      return this.size instanceof LogicalSize ? this.size : this.size.toLogical(scaleFactor);
    }
    toPhysical(scaleFactor) {
      return this.size instanceof PhysicalSize ? this.size : this.size.toPhysical(scaleFactor);
    }
    [SERIALIZE_TO_IPC_FN]() {
      return {
        [`${this.size.type}`]: {
          width: this.size.width,
          height: this.size.height
        }
      };
    }
    toJSON() {
      return this[SERIALIZE_TO_IPC_FN]();
    }
  };
  var LogicalPosition = class {
    constructor(...args) {
      this.type = "Logical";
      if (args.length === 1) {
        if ("Logical" in args[0]) {
          this.x = args[0].Logical.x;
          this.y = args[0].Logical.y;
        } else {
          this.x = args[0].x;
          this.y = args[0].y;
        }
      } else {
        this.x = args[0];
        this.y = args[1];
      }
    }
    /**
     * Converts the logical position to a physical one.
     * @example
     * ```typescript
     * import { LogicalPosition } from '@tauri-apps/api/dpi';
     * import { getCurrentWindow } from '@tauri-apps/api/window';
     *
     * const appWindow = getCurrentWindow();
     * const factor = await appWindow.scaleFactor();
     * const position = new LogicalPosition(400, 500);
     * const physical = position.toPhysical(factor);
     * ```
     *
     * @since 2.0.0
     */
    toPhysical(scaleFactor) {
      return new PhysicalPosition(this.x * scaleFactor, this.y * scaleFactor);
    }
    [SERIALIZE_TO_IPC_FN]() {
      return {
        x: this.x,
        y: this.y
      };
    }
    toJSON() {
      return this[SERIALIZE_TO_IPC_FN]();
    }
  };
  var PhysicalPosition = class {
    constructor(...args) {
      this.type = "Physical";
      if (args.length === 1) {
        if ("Physical" in args[0]) {
          this.x = args[0].Physical.x;
          this.y = args[0].Physical.y;
        } else {
          this.x = args[0].x;
          this.y = args[0].y;
        }
      } else {
        this.x = args[0];
        this.y = args[1];
      }
    }
    /**
     * Converts the physical position to a logical one.
     * @example
     * ```typescript
     * import { PhysicalPosition } from '@tauri-apps/api/dpi';
     * import { getCurrentWindow } from '@tauri-apps/api/window';
     *
     * const appWindow = getCurrentWindow();
     * const factor = await appWindow.scaleFactor();
     * const position = new PhysicalPosition(400, 500);
     * const physical = position.toLogical(factor);
     * ```
     *
     * @since 2.0.0
     */
    toLogical(scaleFactor) {
      return new LogicalPosition(this.x / scaleFactor, this.y / scaleFactor);
    }
    [SERIALIZE_TO_IPC_FN]() {
      return {
        x: this.x,
        y: this.y
      };
    }
    toJSON() {
      return this[SERIALIZE_TO_IPC_FN]();
    }
  };
  var Position = class {
    constructor(position) {
      this.position = position;
    }
    toLogical(scaleFactor) {
      return this.position instanceof LogicalPosition ? this.position : this.position.toLogical(scaleFactor);
    }
    toPhysical(scaleFactor) {
      return this.position instanceof PhysicalPosition ? this.position : this.position.toPhysical(scaleFactor);
    }
    [SERIALIZE_TO_IPC_FN]() {
      return {
        [`${this.position.type}`]: {
          x: this.position.x,
          y: this.position.y
        }
      };
    }
    toJSON() {
      return this[SERIALIZE_TO_IPC_FN]();
    }
  };

  // node_modules/@tauri-apps/api/event.js
  var TauriEvent;
  (function(TauriEvent2) {
    TauriEvent2["WINDOW_RESIZED"] = "tauri://resize";
    TauriEvent2["WINDOW_MOVED"] = "tauri://move";
    TauriEvent2["WINDOW_CLOSE_REQUESTED"] = "tauri://close-requested";
    TauriEvent2["WINDOW_DESTROYED"] = "tauri://destroyed";
    TauriEvent2["WINDOW_FOCUS"] = "tauri://focus";
    TauriEvent2["WINDOW_BLUR"] = "tauri://blur";
    TauriEvent2["WINDOW_SCALE_FACTOR_CHANGED"] = "tauri://scale-change";
    TauriEvent2["WINDOW_THEME_CHANGED"] = "tauri://theme-changed";
    TauriEvent2["WINDOW_CREATED"] = "tauri://window-created";
    TauriEvent2["WINDOW_SUSPENDED"] = "tauri://suspended";
    TauriEvent2["WINDOW_RESUMED"] = "tauri://resumed";
    TauriEvent2["WEBVIEW_CREATED"] = "tauri://webview-created";
    TauriEvent2["DRAG_ENTER"] = "tauri://drag-enter";
    TauriEvent2["DRAG_OVER"] = "tauri://drag-over";
    TauriEvent2["DRAG_DROP"] = "tauri://drag-drop";
    TauriEvent2["DRAG_LEAVE"] = "tauri://drag-leave";
  })(TauriEvent || (TauriEvent = {}));
  async function _unlisten(event, eventId) {
    window.__TAURI_EVENT_PLUGIN_INTERNALS__.unregisterListener(event, eventId);
    await invoke("plugin:event|unlisten", {
      event,
      eventId
    });
  }
  async function listen(event, handler, options) {
    var _a;
    const target = typeof (options === null || options === void 0 ? void 0 : options.target) === "string" ? { kind: "AnyLabel", label: options.target } : (_a = options === null || options === void 0 ? void 0 : options.target) !== null && _a !== void 0 ? _a : { kind: "Any" };
    return invoke("plugin:event|listen", {
      event,
      target,
      handler: transformCallback(handler)
    }).then((eventId) => {
      return async () => _unlisten(event, eventId);
    });
  }
  async function once(event, handler, options) {
    return listen(event, (eventData) => {
      void _unlisten(event, eventData.id);
      handler(eventData);
    }, options);
  }
  async function emit(event, payload) {
    await invoke("plugin:event|emit", {
      event,
      payload
    });
  }
  async function emitTo(target, event, payload) {
    const eventTarget = typeof target === "string" ? { kind: "AnyLabel", label: target } : target;
    await invoke("plugin:event|emit_to", {
      target: eventTarget,
      event,
      payload
    });
  }

  // node_modules/@tauri-apps/api/image.js
  var Image = class _Image extends Resource {
    /**
     * Creates an Image from a resource ID. For internal use only.
     *
     * @ignore
     */
    constructor(rid) {
      super(rid);
    }
    /** Creates a new Image using RGBA data, in row-major order from top to bottom, and with specified width and height. */
    static async new(rgba, width, height) {
      return invoke("plugin:image|new", {
        rgba: transformImage(rgba),
        width,
        height
      }).then((rid) => new _Image(rid));
    }
    /**
     * Creates a new image using the provided bytes by inferring the file format.
     * If the format is known, prefer [@link Image.fromPngBytes] or [@link Image.fromIcoBytes].
     *
     * Only `ico` and `png` are supported (based on activated feature flag).
     *
     * Note that you need the `image-ico` or `image-png` Cargo features to use this API.
     * To enable it, change your Cargo.toml file:
     * ```toml
     * [dependencies]
     * tauri = { version = "...", features = ["...", "image-png"] }
     * ```
     */
    static async fromBytes(bytes) {
      return invoke("plugin:image|from_bytes", {
        bytes: transformImage(bytes)
      }).then((rid) => new _Image(rid));
    }
    /**
     * Creates a new image using the provided path.
     *
     * Only `ico` and `png` are supported (based on activated feature flag).
     *
     * Note that you need the `image-ico` or `image-png` Cargo features to use this API.
     * To enable it, change your Cargo.toml file:
     * ```toml
     * [dependencies]
     * tauri = { version = "...", features = ["...", "image-png"] }
     * ```
     */
    static async fromPath(path2) {
      return invoke("plugin:image|from_path", { path: path2 }).then((rid) => new _Image(rid));
    }
    /** Returns the RGBA data for this image, in row-major order from top to bottom.  */
    async rgba() {
      return invoke("plugin:image|rgba", {
        rid: this.rid
      }).then((buffer) => new Uint8Array(buffer));
    }
    /** Returns the size of this image.  */
    async size() {
      return invoke("plugin:image|size", { rid: this.rid });
    }
  };
  function transformImage(image) {
    const ret = image == null ? null : typeof image === "string" ? image : image instanceof Image ? image.rid : image;
    return ret;
  }

  // node_modules/@tauri-apps/api/window.js
  var UserAttentionType;
  (function(UserAttentionType2) {
    UserAttentionType2[UserAttentionType2["Critical"] = 1] = "Critical";
    UserAttentionType2[UserAttentionType2["Informational"] = 2] = "Informational";
  })(UserAttentionType || (UserAttentionType = {}));
  var CloseRequestedEvent = class {
    constructor(event) {
      this._preventDefault = false;
      this.event = event.event;
      this.id = event.id;
    }
    preventDefault() {
      this._preventDefault = true;
    }
    isPreventDefault() {
      return this._preventDefault;
    }
  };
  var ProgressBarStatus;
  (function(ProgressBarStatus2) {
    ProgressBarStatus2["None"] = "none";
    ProgressBarStatus2["Normal"] = "normal";
    ProgressBarStatus2["Indeterminate"] = "indeterminate";
    ProgressBarStatus2["Paused"] = "paused";
    ProgressBarStatus2["Error"] = "error";
  })(ProgressBarStatus || (ProgressBarStatus = {}));
  function getCurrentWindow() {
    return new Window(window.__TAURI_INTERNALS__.metadata.currentWindow.label, {
      // @ts-expect-error `skip` is not defined in the public API but it is handled by the constructor
      skip: true
    });
  }
  async function getAllWindows() {
    return invoke("plugin:window|get_all_windows").then((windows) => windows.map((w) => new Window(w, {
      // @ts-expect-error `skip` is not defined in the public API but it is handled by the constructor
      skip: true
    })));
  }
  var localTauriEvents = ["tauri://created", "tauri://error"];
  var Window = class {
    /**
     * Creates a new Window.
     * @example
     * ```typescript
     * import { Window } from '@tauri-apps/api/window';
     * const appWindow = new Window('my-label');
     * appWindow.once('tauri://created', function () {
     *  // window successfully created
     * });
     * appWindow.once('tauri://error', function (e) {
     *  // an error happened creating the window
     * });
     * ```
     *
     * @param label The unique window label. Must be alphanumeric: `a-zA-Z-/:_`.
     * @returns The {@link Window} instance to communicate with the window.
     */
    constructor(label, options = {}) {
      var _a;
      this.label = label;
      this.listeners = /* @__PURE__ */ Object.create(null);
      if (!(options === null || options === void 0 ? void 0 : options.skip)) {
        invoke("plugin:window|create", {
          options: {
            ...options,
            parent: typeof options.parent === "string" ? options.parent : (_a = options.parent) === null || _a === void 0 ? void 0 : _a.label,
            label
          }
        }).then(async () => this.emit("tauri://created")).catch(async (e) => this.emit("tauri://error", e));
      }
    }
    /**
     * Gets the Window associated with the given label.
     * @example
     * ```typescript
     * import { Window } from '@tauri-apps/api/window';
     * const mainWindow = Window.getByLabel('main');
     * ```
     *
     * @param label The window label.
     * @returns The Window instance to communicate with the window or null if the window doesn't exist.
     */
    static async getByLabel(label) {
      var _a;
      return (_a = (await getAllWindows()).find((w) => w.label === label)) !== null && _a !== void 0 ? _a : null;
    }
    /**
     * Get an instance of `Window` for the current window.
     */
    static getCurrent() {
      return getCurrentWindow();
    }
    /**
     * Gets a list of instances of `Window` for all available windows.
     */
    static async getAll() {
      return getAllWindows();
    }
    /**
     *  Gets the focused window.
     * @example
     * ```typescript
     * import { Window } from '@tauri-apps/api/window';
     * const focusedWindow = Window.getFocusedWindow();
     * ```
     *
     * @returns The Window instance or `undefined` if there is not any focused window.
     */
    static async getFocusedWindow() {
      for (const w of await getAllWindows()) {
        if (await w.isFocused()) {
          return w;
        }
      }
      return null;
    }
    /**
     * Listen to an emitted event on this window.
     *
     * @example
     * ```typescript
     * import { getCurrentWindow } from '@tauri-apps/api/window';
     * const unlisten = await getCurrentWindow().listen<string>('state-changed', (event) => {
     *   console.log(`Got error: ${payload}`);
     * });
     *
     * // you need to call unlisten if your handler goes out of scope e.g. the component is unmounted
     * unlisten();
     * ```
     *
     * @param event Event name. Must include only alphanumeric characters, `-`, `/`, `:` and `_`.
     * @param handler Event handler.
     * @returns A promise resolving to a function to unlisten to the event.
     * Note that removing the listener is required if your listener goes out of scope e.g. the component is unmounted.
     */
    async listen(event, handler) {
      if (this._handleTauriEvent(event, handler)) {
        return () => {
          const listeners = this.listeners[event];
          listeners.splice(listeners.indexOf(handler), 1);
        };
      }
      return listen(event, handler, {
        target: { kind: "Window", label: this.label }
      });
    }
    /**
     * Listen to an emitted event on this window only once.
     *
     * @example
     * ```typescript
     * import { getCurrentWindow } from '@tauri-apps/api/window';
     * const unlisten = await getCurrentWindow().once<null>('initialized', (event) => {
     *   console.log(`Window initialized!`);
     * });
     *
     * // you need to call unlisten if your handler goes out of scope e.g. the component is unmounted
     * unlisten();
     * ```
     *
     * @param event Event name. Must include only alphanumeric characters, `-`, `/`, `:` and `_`.
     * @param handler Event handler.
     * @returns A promise resolving to a function to unlisten to the event.
     * Note that removing the listener is required if your listener goes out of scope e.g. the component is unmounted.
     */
    async once(event, handler) {
      if (this._handleTauriEvent(event, handler)) {
        return () => {
          const listeners = this.listeners[event];
          listeners.splice(listeners.indexOf(handler), 1);
        };
      }
      return once(event, handler, {
        target: { kind: "Window", label: this.label }
      });
    }
    /**
     * Emits an event to all {@link EventTarget|targets}.
     * @example
     * ```typescript
     * import { getCurrentWindow } from '@tauri-apps/api/window';
     * await getCurrentWindow().emit('window-loaded', { loggedIn: true, token: 'authToken' });
     * ```
     *
     * @param event Event name. Must include only alphanumeric characters, `-`, `/`, `:` and `_`.
     * @param payload Event payload.
     */
    async emit(event, payload) {
      if (localTauriEvents.includes(event)) {
        for (const handler of this.listeners[event] || []) {
          handler({
            event,
            id: -1,
            payload
          });
        }
        return;
      }
      return emit(event, payload);
    }
    /**
     * Emits an event to all {@link EventTarget|targets} matching the given target.
     *
     * @example
     * ```typescript
     * import { getCurrentWindow } from '@tauri-apps/api/window';
     * await getCurrentWindow().emit('main', 'window-loaded', { loggedIn: true, token: 'authToken' });
     * ```
     * @param target Label of the target Window/Webview/WebviewWindow or raw {@link EventTarget} object.
     * @param event Event name. Must include only alphanumeric characters, `-`, `/`, `:` and `_`.
     * @param payload Event payload.
     */
    async emitTo(target, event, payload) {
      if (localTauriEvents.includes(event)) {
        for (const handler of this.listeners[event] || []) {
          handler({
            event,
            id: -1,
            payload
          });
        }
        return;
      }
      return emitTo(target, event, payload);
    }
    /** @ignore */
    _handleTauriEvent(event, handler) {
      if (localTauriEvents.includes(event)) {
        if (!(event in this.listeners)) {
          this.listeners[event] = [handler];
        } else {
          this.listeners[event].push(handler);
        }
        return true;
      }
      return false;
    }
    // Getters
    /**
     * The scale factor that can be used to map physical pixels to logical pixels.
     * @example
     * ```typescript
     * import { getCurrentWindow } from '@tauri-apps/api/window';
     * const factor = await getCurrentWindow().scaleFactor();
     * ```
     *
     * @returns The window's monitor scale factor.
     */
    async scaleFactor() {
      return invoke("plugin:window|scale_factor", {
        label: this.label
      });
    }
    /**
     * The position of the top-left hand corner of the window's client area relative to the top-left hand corner of the desktop.
     * @example
     * ```typescript
     * import { getCurrentWindow } from '@tauri-apps/api/window';
     * const position = await getCurrentWindow().innerPosition();
     * ```
     *
     * @returns The window's inner position.
     */
    async innerPosition() {
      return invoke("plugin:window|inner_position", {
        label: this.label
      }).then((p) => new PhysicalPosition(p));
    }
    /**
     * The position of the top-left hand corner of the window relative to the top-left hand corner of the desktop.
     * @example
     * ```typescript
     * import { getCurrentWindow } from '@tauri-apps/api/window';
     * const position = await getCurrentWindow().outerPosition();
     * ```
     *
     * @returns The window's outer position.
     */
    async outerPosition() {
      return invoke("plugin:window|outer_position", {
        label: this.label
      }).then((p) => new PhysicalPosition(p));
    }
    /**
     * The physical size of the window's client area.
     * The client area is the content of the window, excluding the title bar and borders.
     * @example
     * ```typescript
     * import { getCurrentWindow } from '@tauri-apps/api/window';
     * const size = await getCurrentWindow().innerSize();
     * ```
     *
     * @returns The window's inner size.
     */
    async innerSize() {
      return invoke("plugin:window|inner_size", {
        label: this.label
      }).then((s) => new PhysicalSize(s));
    }
    /**
     * The physical size of the entire window.
     * These dimensions include the title bar and borders. If you don't want that (and you usually don't), use inner_size instead.
     * @example
     * ```typescript
     * import { getCurrentWindow } from '@tauri-apps/api/window';
     * const size = await getCurrentWindow().outerSize();
     * ```
     *
     * @returns The window's outer size.
     */
    async outerSize() {
      return invoke("plugin:window|outer_size", {
        label: this.label
      }).then((s) => new PhysicalSize(s));
    }
    /**
     * Gets the window's current fullscreen state.
     * @example
     * ```typescript
     * import { getCurrentWindow } from '@tauri-apps/api/window';
     * const fullscreen = await getCurrentWindow().isFullscreen();
     * ```
     *
     * @returns Whether the window is in fullscreen mode or not.
     */
    async isFullscreen() {
      return invoke("plugin:window|is_fullscreen", {
        label: this.label
      });
    }
    /**
     * Gets the window's current minimized state.
     * @example
     * ```typescript
     * import { getCurrentWindow } from '@tauri-apps/api/window';
     * const minimized = await getCurrentWindow().isMinimized();
     * ```
     */
    async isMinimized() {
      return invoke("plugin:window|is_minimized", {
        label: this.label
      });
    }
    /**
     * Gets the window's current maximized state.
     * @example
     * ```typescript
     * import { getCurrentWindow } from '@tauri-apps/api/window';
     * const maximized = await getCurrentWindow().isMaximized();
     * ```
     *
     * @returns Whether the window is maximized or not.
     */
    async isMaximized() {
      return invoke("plugin:window|is_maximized", {
        label: this.label
      });
    }
    /**
     * Gets the window's current focus state.
     * @example
     * ```typescript
     * import { getCurrentWindow } from '@tauri-apps/api/window';
     * const focused = await getCurrentWindow().isFocused();
     * ```
     *
     * @returns Whether the window is focused or not.
     */
    async isFocused() {
      return invoke("plugin:window|is_focused", {
        label: this.label
      });
    }
    /**
     * Gets the window's current decorated state.
     * @example
     * ```typescript
     * import { getCurrentWindow } from '@tauri-apps/api/window';
     * const decorated = await getCurrentWindow().isDecorated();
     * ```
     *
     * @returns Whether the window is decorated or not.
     */
    async isDecorated() {
      return invoke("plugin:window|is_decorated", {
        label: this.label
      });
    }
    /**
     * Gets the window's current resizable state.
     * @example
     * ```typescript
     * import { getCurrentWindow } from '@tauri-apps/api/window';
     * const resizable = await getCurrentWindow().isResizable();
     * ```
     *
     * @returns Whether the window is resizable or not.
     */
    async isResizable() {
      return invoke("plugin:window|is_resizable", {
        label: this.label
      });
    }
    /**
     * Gets the window's native maximize button state.
     *
     * #### Platform-specific
     *
     * - **Linux / iOS / Android:** Unsupported.
     *
     * @example
     * ```typescript
     * import { getCurrentWindow } from '@tauri-apps/api/window';
     * const maximizable = await getCurrentWindow().isMaximizable();
     * ```
     *
     * @returns Whether the window's native maximize button is enabled or not.
     */
    async isMaximizable() {
      return invoke("plugin:window|is_maximizable", {
        label: this.label
      });
    }
    /**
     * Gets the window's native minimize button state.
     *
     * #### Platform-specific
     *
     * - **Linux / iOS / Android:** Unsupported.
     *
     * @example
     * ```typescript
     * import { getCurrentWindow } from '@tauri-apps/api/window';
     * const minimizable = await getCurrentWindow().isMinimizable();
     * ```
     *
     * @returns Whether the window's native minimize button is enabled or not.
     */
    async isMinimizable() {
      return invoke("plugin:window|is_minimizable", {
        label: this.label
      });
    }
    /**
     * Gets the window's native close button state.
     *
     * #### Platform-specific
     *
     * - **iOS / Android:** Unsupported.
     *
     * @example
     * ```typescript
     * import { getCurrentWindow } from '@tauri-apps/api/window';
     * const closable = await getCurrentWindow().isClosable();
     * ```
     *
     * @returns Whether the window's native close button is enabled or not.
     */
    async isClosable() {
      return invoke("plugin:window|is_closable", {
        label: this.label
      });
    }
    /**
     * Gets the window's current visible state.
     * @example
     * ```typescript
     * import { getCurrentWindow } from '@tauri-apps/api/window';
     * const visible = await getCurrentWindow().isVisible();
     * ```
     *
     * @returns Whether the window is visible or not.
     */
    async isVisible() {
      return invoke("plugin:window|is_visible", {
        label: this.label
      });
    }
    /**
     * Gets the window's current title.
     * @example
     * ```typescript
     * import { getCurrentWindow } from '@tauri-apps/api/window';
     * const title = await getCurrentWindow().title();
     * ```
     */
    async title() {
      return invoke("plugin:window|title", {
        label: this.label
      });
    }
    /**
     * Gets the window's current theme.
     *
     * #### Platform-specific
     *
     * - **macOS:** Theme was introduced on macOS 10.14. Returns `light` on macOS 10.13 and below.
     *
     * @example
     * ```typescript
     * import { getCurrentWindow } from '@tauri-apps/api/window';
     * const theme = await getCurrentWindow().theme();
     * ```
     *
     * @returns The window theme.
     */
    async theme() {
      return invoke("plugin:window|theme", {
        label: this.label
      });
    }
    /**
     * Whether the window is configured to be always on top of other windows or not.
     * @example
     * ```typescript
     * import { getCurrentWindow } from '@tauri-apps/api/window';
     * const alwaysOnTop = await getCurrentWindow().isAlwaysOnTop();
     * ```
     *
     * @returns Whether the window is visible or not.
     */
    async isAlwaysOnTop() {
      return invoke("plugin:window|is_always_on_top", {
        label: this.label
      });
    }
    async activityName() {
      return invoke("plugin:window|activity_name", {
        label: this.label
      });
    }
    async sceneIdentifier() {
      return invoke("plugin:window|scene_identifier", {
        label: this.label
      });
    }
    // Setters
    /**
     * Centers the window.
     * @example
     * ```typescript
     * import { getCurrentWindow } from '@tauri-apps/api/window';
     * await getCurrentWindow().center();
     * ```
     *
     * @returns A promise indicating the success or failure of the operation.
     */
    async center() {
      return invoke("plugin:window|center", {
        label: this.label
      });
    }
    /**
     *  Requests user attention to the window, this has no effect if the application
     * is already focused. How requesting for user attention manifests is platform dependent,
     * see `UserAttentionType` for details.
     *
     * Providing `null` will unset the request for user attention. Unsetting the request for
     * user attention might not be done automatically by the WM when the window receives input.
     *
     * #### Platform-specific
     *
     * - **macOS:** `null` has no effect.
     * - **Linux:** Urgency levels have the same effect.
     * @example
     * ```typescript
     * import { getCurrentWindow } from '@tauri-apps/api/window';
     * await getCurrentWindow().requestUserAttention();
     * ```
     *
     * @returns A promise indicating the success or failure of the operation.
     */
    async requestUserAttention(requestType) {
      let requestType_ = null;
      if (requestType) {
        if (requestType === UserAttentionType.Critical) {
          requestType_ = { type: "Critical" };
        } else {
          requestType_ = { type: "Informational" };
        }
      }
      return invoke("plugin:window|request_user_attention", {
        label: this.label,
        value: requestType_
      });
    }
    /**
     * Updates the window resizable flag.
     * @example
     * ```typescript
     * import { getCurrentWindow } from '@tauri-apps/api/window';
     * await getCurrentWindow().setResizable(false);
     * ```
     *
     * @returns A promise indicating the success or failure of the operation.
     */
    async setResizable(resizable) {
      return invoke("plugin:window|set_resizable", {
        label: this.label,
        value: resizable
      });
    }
    /**
     * Enable or disable the window.
     * @example
     * ```typescript
     * import { getCurrentWindow } from '@tauri-apps/api/window';
     * await getCurrentWindow().setEnabled(false);
     * ```
     *
     * @returns A promise indicating the success or failure of the operation.
     *
     * @since 2.0.0
     */
    async setEnabled(enabled) {
      return invoke("plugin:window|set_enabled", {
        label: this.label,
        value: enabled
      });
    }
    /**
     * Whether the window is enabled or disabled.
     * @example
     * ```typescript
     * import { getCurrentWindow } from '@tauri-apps/api/window';
     * await getCurrentWindow().setEnabled(false);
     * ```
     *
     * @returns A promise indicating the success or failure of the operation.
     *
     * @since 2.0.0
     */
    async isEnabled() {
      return invoke("plugin:window|is_enabled", {
        label: this.label
      });
    }
    /**
     * Sets whether the window's native maximize button is enabled or not.
     * If resizable is set to false, this setting is ignored.
     *
     * #### Platform-specific
     *
     * - **macOS:** Disables the "zoom" button in the window titlebar, which is also used to enter fullscreen mode.
     * - **Linux / iOS / Android:** Unsupported.
     *
     * @example
     * ```typescript
     * import { getCurrentWindow } from '@tauri-apps/api/window';
     * await getCurrentWindow().setMaximizable(false);
     * ```
     *
     * @returns A promise indicating the success or failure of the operation.
     */
    async setMaximizable(maximizable) {
      return invoke("plugin:window|set_maximizable", {
        label: this.label,
        value: maximizable
      });
    }
    /**
     * Sets whether the window's native minimize button is enabled or not.
     *
     * #### Platform-specific
     *
     * - **Linux / iOS / Android:** Unsupported.
     *
     * @example
     * ```typescript
     * import { getCurrentWindow } from '@tauri-apps/api/window';
     * await getCurrentWindow().setMinimizable(false);
     * ```
     *
     * @returns A promise indicating the success or failure of the operation.
     */
    async setMinimizable(minimizable) {
      return invoke("plugin:window|set_minimizable", {
        label: this.label,
        value: minimizable
      });
    }
    /**
     * Sets whether the window's native close button is enabled or not.
     *
     * #### Platform-specific
     *
     * - **Linux:** GTK+ will do its best to convince the window manager not to show a close button. Depending on the system, this function may not have any effect when called on a window that is already visible
     * - **iOS / Android:** Unsupported.
     *
     * @example
     * ```typescript
     * import { getCurrentWindow } from '@tauri-apps/api/window';
     * await getCurrentWindow().setClosable(false);
     * ```
     *
     * @returns A promise indicating the success or failure of the operation.
     */
    async setClosable(closable) {
      return invoke("plugin:window|set_closable", {
        label: this.label,
        value: closable
      });
    }
    /**
     * Sets the window title.
     * @example
     * ```typescript
     * import { getCurrentWindow } from '@tauri-apps/api/window';
     * await getCurrentWindow().setTitle('Tauri');
     * ```
     *
     * @param title The new title
     * @returns A promise indicating the success or failure of the operation.
     */
    async setTitle(title) {
      return invoke("plugin:window|set_title", {
        label: this.label,
        value: title
      });
    }
    /**
     * Maximizes the window.
     * @example
     * ```typescript
     * import { getCurrentWindow } from '@tauri-apps/api/window';
     * await getCurrentWindow().maximize();
     * ```
     *
     * @returns A promise indicating the success or failure of the operation.
     */
    async maximize() {
      return invoke("plugin:window|maximize", {
        label: this.label
      });
    }
    /**
     * Unmaximizes the window.
     * @example
     * ```typescript
     * import { getCurrentWindow } from '@tauri-apps/api/window';
     * await getCurrentWindow().unmaximize();
     * ```
     *
     * @returns A promise indicating the success or failure of the operation.
     */
    async unmaximize() {
      return invoke("plugin:window|unmaximize", {
        label: this.label
      });
    }
    /**
     * Toggles the window maximized state.
     * @example
     * ```typescript
     * import { getCurrentWindow } from '@tauri-apps/api/window';
     * await getCurrentWindow().toggleMaximize();
     * ```
     *
     * @returns A promise indicating the success or failure of the operation.
     */
    async toggleMaximize() {
      return invoke("plugin:window|toggle_maximize", {
        label: this.label
      });
    }
    /**
     * Minimizes the window.
     * @example
     * ```typescript
     * import { getCurrentWindow } from '@tauri-apps/api/window';
     * await getCurrentWindow().minimize();
     * ```
     *
     * @returns A promise indicating the success or failure of the operation.
     */
    async minimize() {
      return invoke("plugin:window|minimize", {
        label: this.label
      });
    }
    /**
     * Unminimizes the window.
     * @example
     * ```typescript
     * import { getCurrentWindow } from '@tauri-apps/api/window';
     * await getCurrentWindow().unminimize();
     * ```
     *
     * @returns A promise indicating the success or failure of the operation.
     */
    async unminimize() {
      return invoke("plugin:window|unminimize", {
        label: this.label
      });
    }
    /**
     * Sets the window visibility to true.
     * @example
     * ```typescript
     * import { getCurrentWindow } from '@tauri-apps/api/window';
     * await getCurrentWindow().show();
     * ```
     *
     * @returns A promise indicating the success or failure of the operation.
     */
    async show() {
      return invoke("plugin:window|show", {
        label: this.label
      });
    }
    /**
     * Sets the window visibility to false.
     * @example
     * ```typescript
     * import { getCurrentWindow } from '@tauri-apps/api/window';
     * await getCurrentWindow().hide();
     * ```
     *
     * @returns A promise indicating the success or failure of the operation.
     */
    async hide() {
      return invoke("plugin:window|hide", {
        label: this.label
      });
    }
    /**
     * Closes the window.
     *
     * Note this emits a closeRequested event so you can intercept it. To force window close, use {@link Window.destroy}.
     * @example
     * ```typescript
     * import { getCurrentWindow } from '@tauri-apps/api/window';
     * await getCurrentWindow().close();
     * ```
     *
     * @returns A promise indicating the success or failure of the operation.
     */
    async close() {
      return invoke("plugin:window|close", {
        label: this.label
      });
    }
    /**
     * Destroys the window. Behaves like {@link Window.close} but forces the window close instead of emitting a closeRequested event.
     * @example
     * ```typescript
     * import { getCurrentWindow } from '@tauri-apps/api/window';
     * await getCurrentWindow().destroy();
     * ```
     *
     * @returns A promise indicating the success or failure of the operation.
     */
    async destroy() {
      return invoke("plugin:window|destroy", {
        label: this.label
      });
    }
    /**
     * Whether the window should have borders and bars.
     * @example
     * ```typescript
     * import { getCurrentWindow } from '@tauri-apps/api/window';
     * await getCurrentWindow().setDecorations(false);
     * ```
     *
     * @param decorations Whether the window should have borders and bars.
     * @returns A promise indicating the success or failure of the operation.
     */
    async setDecorations(decorations) {
      return invoke("plugin:window|set_decorations", {
        label: this.label,
        value: decorations
      });
    }
    /**
     * Whether or not the window should have shadow.
     *
     * #### Platform-specific
     *
     * - **Windows:**
     *   - `false` has no effect on decorated window, shadows are always ON.
     *   - `true` will make undecorated window have a 1px white border,
     * and on Windows 11, it will have a rounded corners.
     * - **Linux:** Unsupported.
     *
     * @example
     * ```typescript
     * import { getCurrentWindow } from '@tauri-apps/api/window';
     * await getCurrentWindow().setShadow(false);
     * ```
     *
     * @returns A promise indicating the success or failure of the operation.
     */
    async setShadow(enable) {
      return invoke("plugin:window|set_shadow", {
        label: this.label,
        value: enable
      });
    }
    /**
     * Set window effects.
     */
    async setEffects(effects) {
      return invoke("plugin:window|set_effects", {
        label: this.label,
        value: effects
      });
    }
    /**
     * Clear any applied effects if possible.
     */
    async clearEffects() {
      return invoke("plugin:window|set_effects", {
        label: this.label,
        value: null
      });
    }
    /**
     * Whether the window should always be on top of other windows.
     * @example
     * ```typescript
     * import { getCurrentWindow } from '@tauri-apps/api/window';
     * await getCurrentWindow().setAlwaysOnTop(true);
     * ```
     *
     * @param alwaysOnTop Whether the window should always be on top of other windows or not.
     * @returns A promise indicating the success or failure of the operation.
     */
    async setAlwaysOnTop(alwaysOnTop) {
      return invoke("plugin:window|set_always_on_top", {
        label: this.label,
        value: alwaysOnTop
      });
    }
    /**
     * Whether the window should always be below other windows.
     * @example
     * ```typescript
     * import { getCurrentWindow } from '@tauri-apps/api/window';
     * await getCurrentWindow().setAlwaysOnBottom(true);
     * ```
     *
     * @param alwaysOnBottom Whether the window should always be below other windows or not.
     * @returns A promise indicating the success or failure of the operation.
     */
    async setAlwaysOnBottom(alwaysOnBottom) {
      return invoke("plugin:window|set_always_on_bottom", {
        label: this.label,
        value: alwaysOnBottom
      });
    }
    /**
     * Prevents the window contents from being captured by other apps.
     * @example
     * ```typescript
     * import { getCurrentWindow } from '@tauri-apps/api/window';
     * await getCurrentWindow().setContentProtected(true);
     * ```
     *
     * @returns A promise indicating the success or failure of the operation.
     */
    async setContentProtected(protected_) {
      return invoke("plugin:window|set_content_protected", {
        label: this.label,
        value: protected_
      });
    }
    /**
     * Resizes the window with a new inner size.
     * @example
     * ```typescript
     * import { getCurrentWindow, LogicalSize } from '@tauri-apps/api/window';
     * await getCurrentWindow().setSize(new LogicalSize(600, 500));
     * ```
     *
     * @param size The logical or physical inner size.
     * @returns A promise indicating the success or failure of the operation.
     */
    async setSize(size) {
      return invoke("plugin:window|set_size", {
        label: this.label,
        value: size instanceof Size ? size : new Size(size)
      });
    }
    /**
     * Sets the window minimum inner size. If the `size` argument is not provided, the constraint is unset.
     * @example
     * ```typescript
     * import { getCurrentWindow, PhysicalSize } from '@tauri-apps/api/window';
     * await getCurrentWindow().setMinSize(new PhysicalSize(600, 500));
     * ```
     *
     * @param size The logical or physical inner size, or `null` to unset the constraint.
     * @returns A promise indicating the success or failure of the operation.
     */
    async setMinSize(size) {
      return invoke("plugin:window|set_min_size", {
        label: this.label,
        value: size instanceof Size ? size : size ? new Size(size) : null
      });
    }
    /**
     * Sets the window maximum inner size. If the `size` argument is undefined, the constraint is unset.
     * @example
     * ```typescript
     * import { getCurrentWindow, LogicalSize } from '@tauri-apps/api/window';
     * await getCurrentWindow().setMaxSize(new LogicalSize(600, 500));
     * ```
     *
     * @param size The logical or physical inner size, or `null` to unset the constraint.
     * @returns A promise indicating the success or failure of the operation.
     */
    async setMaxSize(size) {
      return invoke("plugin:window|set_max_size", {
        label: this.label,
        value: size instanceof Size ? size : size ? new Size(size) : null
      });
    }
    /**
     * Sets the window inner size constraints.
     * @example
     * ```typescript
     * import { getCurrentWindow } from '@tauri-apps/api/window';
     * await getCurrentWindow().setSizeConstraints({ minWidth: 300 });
     * ```
     *
     * @param constraints The logical or physical inner size, or `null` to unset the constraint.
     * @returns A promise indicating the success or failure of the operation.
     */
    async setSizeConstraints(constraints) {
      function logical(pixel) {
        return pixel ? { Logical: pixel } : null;
      }
      return invoke("plugin:window|set_size_constraints", {
        label: this.label,
        value: {
          minWidth: logical(constraints === null || constraints === void 0 ? void 0 : constraints.minWidth),
          minHeight: logical(constraints === null || constraints === void 0 ? void 0 : constraints.minHeight),
          maxWidth: logical(constraints === null || constraints === void 0 ? void 0 : constraints.maxWidth),
          maxHeight: logical(constraints === null || constraints === void 0 ? void 0 : constraints.maxHeight)
        }
      });
    }
    /**
     * Sets the window outer position.
     * @example
     * ```typescript
     * import { getCurrentWindow, LogicalPosition } from '@tauri-apps/api/window';
     * await getCurrentWindow().setPosition(new LogicalPosition(600, 500));
     * ```
     *
     * @param position The new position, in logical or physical pixels.
     * @returns A promise indicating the success or failure of the operation.
     */
    async setPosition(position) {
      return invoke("plugin:window|set_position", {
        label: this.label,
        value: position instanceof Position ? position : new Position(position)
      });
    }
    /**
     * Sets the window fullscreen state.
     * @example
     * ```typescript
     * import { getCurrentWindow } from '@tauri-apps/api/window';
     * await getCurrentWindow().setFullscreen(true);
     * ```
     *
     * @param fullscreen Whether the window should go to fullscreen or not.
     * @returns A promise indicating the success or failure of the operation.
     */
    async setFullscreen(fullscreen) {
      return invoke("plugin:window|set_fullscreen", {
        label: this.label,
        value: fullscreen
      });
    }
    /**
     * On macOS, Toggles a fullscreen mode that doesn’t require a new macOS space. Returns a boolean indicating whether the transition was successful (this won’t work if the window was already in the native fullscreen).
     * This is how fullscreen used to work on macOS in versions before Lion. And allows the user to have a fullscreen window without using another space or taking control over the entire monitor.
     *
     * On other platforms, this is the same as {@link Window.setFullscreen}.
     *
     * @param fullscreen Whether the window should go to simple fullscreen or not.
     * @returns A promise indicating the success or failure of the operation.
     */
    async setSimpleFullscreen(fullscreen) {
      return invoke("plugin:window|set_simple_fullscreen", {
        label: this.label,
        value: fullscreen
      });
    }
    /**
     * Bring the window to front and focus.
     * @example
     * ```typescript
     * import { getCurrentWindow } from '@tauri-apps/api/window';
     * await getCurrentWindow().setFocus();
     * ```
     *
     * @returns A promise indicating the success or failure of the operation.
     */
    async setFocus() {
      return invoke("plugin:window|set_focus", {
        label: this.label
      });
    }
    /**
     * Sets whether the window can be focused.
     *
     * #### Platform-specific
     *
     * - **macOS**: If the window is already focused, it is not possible to unfocus it after calling `set_focusable(false)`.
     *   In this case, you might consider calling {@link Window.setFocus} but it will move the window to the back i.e. at the bottom in terms of z-order.
     *
     * @example
     * ```typescript
     * import { getCurrentWindow } from '@tauri-apps/api/window';
     * await getCurrentWindow().setFocusable(true);
     * ```
     *
     * @param focusable Whether the window can be focused.
     * @returns A promise indicating the success or failure of the operation.
     */
    async setFocusable(focusable) {
      return invoke("plugin:window|set_focusable", {
        label: this.label,
        value: focusable
      });
    }
    /**
     * Sets the window icon.
     * @example
     * ```typescript
     * import { getCurrentWindow } from '@tauri-apps/api/window';
     * await getCurrentWindow().setIcon('/tauri/awesome.png');
     * ```
     *
     * Note that you may need the `image-ico` or `image-png` Cargo features to use this API.
     * To enable it, change your Cargo.toml file:
     * ```toml
     * [dependencies]
     * tauri = { version = "...", features = ["...", "image-png"] }
     * ```
     *
     * @param icon Icon bytes or path to the icon file.
     * @returns A promise indicating the success or failure of the operation.
     */
    async setIcon(icon) {
      return invoke("plugin:window|set_icon", {
        label: this.label,
        value: transformImage(icon)
      });
    }
    /**
     * Whether the window icon should be hidden from the taskbar or not.
     *
     * #### Platform-specific
     *
     * - **macOS:** Unsupported.
     * @example
     * ```typescript
     * import { getCurrentWindow } from '@tauri-apps/api/window';
     * await getCurrentWindow().setSkipTaskbar(true);
     * ```
     *
     * @param skip true to hide window icon, false to show it.
     * @returns A promise indicating the success or failure of the operation.
     */
    async setSkipTaskbar(skip) {
      return invoke("plugin:window|set_skip_taskbar", {
        label: this.label,
        value: skip
      });
    }
    /**
     * Grabs the cursor, preventing it from leaving the window.
     *
     * There's no guarantee that the cursor will be hidden. You should
     * hide it by yourself if you want so.
     *
     * #### Platform-specific
     *
     * - **Linux:** Unsupported.
     * - **macOS:** This locks the cursor in a fixed location, which looks visually awkward.
     * @example
     * ```typescript
     * import { getCurrentWindow } from '@tauri-apps/api/window';
     * await getCurrentWindow().setCursorGrab(true);
     * ```
     *
     * @param grab `true` to grab the cursor icon, `false` to release it.
     * @returns A promise indicating the success or failure of the operation.
     */
    async setCursorGrab(grab) {
      return invoke("plugin:window|set_cursor_grab", {
        label: this.label,
        value: grab
      });
    }
    /**
     * Modifies the cursor's visibility.
     *
     * #### Platform-specific
     *
     * - **Windows:** The cursor is only hidden within the confines of the window.
     * - **macOS:** The cursor is hidden as long as the window has input focus, even if the cursor is
     *   outside of the window.
     * @example
     * ```typescript
     * import { getCurrentWindow } from '@tauri-apps/api/window';
     * await getCurrentWindow().setCursorVisible(false);
     * ```
     *
     * @param visible If `false`, this will hide the cursor. If `true`, this will show the cursor.
     * @returns A promise indicating the success or failure of the operation.
     */
    async setCursorVisible(visible) {
      return invoke("plugin:window|set_cursor_visible", {
        label: this.label,
        value: visible
      });
    }
    /**
     * Modifies the cursor icon of the window.
     * @example
     * ```typescript
     * import { getCurrentWindow } from '@tauri-apps/api/window';
     * await getCurrentWindow().setCursorIcon('help');
     * ```
     *
     * @param icon The new cursor icon.
     * @returns A promise indicating the success or failure of the operation.
     */
    async setCursorIcon(icon) {
      return invoke("plugin:window|set_cursor_icon", {
        label: this.label,
        value: icon
      });
    }
    /**
     * Sets the window background color.
     *
     * #### Platform-specific:
     *
     * - **Windows:** alpha channel is ignored.
     * - **iOS / Android:** Unsupported.
     *
     * @returns A promise indicating the success or failure of the operation.
     *
     * @since 2.1.0
     */
    async setBackgroundColor(color) {
      return invoke("plugin:window|set_background_color", { color });
    }
    /**
     * Changes the position of the cursor in window coordinates.
     * @example
     * ```typescript
     * import { getCurrentWindow, LogicalPosition } from '@tauri-apps/api/window';
     * await getCurrentWindow().setCursorPosition(new LogicalPosition(600, 300));
     * ```
     *
     * @param position The new cursor position.
     * @returns A promise indicating the success or failure of the operation.
     */
    async setCursorPosition(position) {
      return invoke("plugin:window|set_cursor_position", {
        label: this.label,
        value: position instanceof Position ? position : new Position(position)
      });
    }
    /**
     * Changes the cursor events behavior.
     *
     * @example
     * ```typescript
     * import { getCurrentWindow } from '@tauri-apps/api/window';
     * await getCurrentWindow().setIgnoreCursorEvents(true);
     * ```
     *
     * @param ignore `true` to ignore the cursor events; `false` to process them as usual.
     * @returns A promise indicating the success or failure of the operation.
     */
    async setIgnoreCursorEvents(ignore) {
      return invoke("plugin:window|set_ignore_cursor_events", {
        label: this.label,
        value: ignore
      });
    }
    /**
     * Starts dragging the window.
     * @example
     * ```typescript
     * import { getCurrentWindow } from '@tauri-apps/api/window';
     * await getCurrentWindow().startDragging();
     * ```
     *
     * @return A promise indicating the success or failure of the operation.
     */
    async startDragging() {
      return invoke("plugin:window|start_dragging", {
        label: this.label
      });
    }
    /**
     * Starts resize-dragging the window.
     * @example
     * ```typescript
     * import { getCurrentWindow } from '@tauri-apps/api/window';
     * await getCurrentWindow().startResizeDragging();
     * ```
     *
     * @return A promise indicating the success or failure of the operation.
     */
    async startResizeDragging(direction) {
      return invoke("plugin:window|start_resize_dragging", {
        label: this.label,
        value: direction
      });
    }
    /**
     * Sets the badge count. It is app wide and not specific to this window.
     *
     * #### Platform-specific
     *
     * - **Windows**: Unsupported. Use @{linkcode Window.setOverlayIcon} instead.
     *
     * @example
     * ```typescript
     * import { getCurrentWindow } from '@tauri-apps/api/window';
     * await getCurrentWindow().setBadgeCount(5);
     * ```
     *
     * @param count The badge count. Use `undefined` to remove the badge.
     * @return A promise indicating the success or failure of the operation.
     */
    async setBadgeCount(count) {
      return invoke("plugin:window|set_badge_count", {
        label: this.label,
        value: count
      });
    }
    /**
     * Sets the badge cont **macOS only**.
     *
     * @example
     * ```typescript
     * import { getCurrentWindow } from '@tauri-apps/api/window';
     * await getCurrentWindow().setBadgeLabel("Hello");
     * ```
     *
     * @param label The badge label. Use `undefined` to remove the badge.
     * @return A promise indicating the success or failure of the operation.
     */
    async setBadgeLabel(label) {
      return invoke("plugin:window|set_badge_label", {
        label: this.label,
        value: label
      });
    }
    /**
     * Sets the overlay icon. **Windows only**
     * The overlay icon can be set for every window.
     *
     *
     * Note that you may need the `image-ico` or `image-png` Cargo features to use this API.
     * To enable it, change your Cargo.toml file:
     *
     * ```toml
     * [dependencies]
     * tauri = { version = "...", features = ["...", "image-png"] }
     * ```
     *
     * @example
     * ```typescript
     * import { getCurrentWindow } from '@tauri-apps/api/window';
     * await getCurrentWindow().setOverlayIcon("/tauri/awesome.png");
     * ```
     *
     * @param icon Icon bytes or path to the icon file. Use `undefined` to remove the overlay icon.
     * @return A promise indicating the success or failure of the operation.
     */
    async setOverlayIcon(icon) {
      return invoke("plugin:window|set_overlay_icon", {
        label: this.label,
        value: icon ? transformImage(icon) : void 0
      });
    }
    /**
     * Sets the taskbar progress state.
     *
     * #### Platform-specific
     *
     * - **Linux / macOS**: Progress bar is app-wide and not specific to this window.
     * - **Linux**: Only supported desktop environments with `libunity` (e.g. GNOME).
     *
     * @example
     * ```typescript
     * import { getCurrentWindow, ProgressBarStatus } from '@tauri-apps/api/window';
     * await getCurrentWindow().setProgressBar({
     *   status: ProgressBarStatus.Normal,
     *   progress: 50,
     * });
     * ```
     *
     * @return A promise indicating the success or failure of the operation.
     */
    async setProgressBar(state) {
      return invoke("plugin:window|set_progress_bar", {
        label: this.label,
        value: state
      });
    }
    /**
     * Sets whether the window should be visible on all workspaces or virtual desktops.
     *
     * #### Platform-specific
     *
     * - **Windows / iOS / Android:** Unsupported.
     *
     * @since 2.0.0
     */
    async setVisibleOnAllWorkspaces(visible) {
      return invoke("plugin:window|set_visible_on_all_workspaces", {
        label: this.label,
        value: visible
      });
    }
    /**
     * Sets the title bar style. **macOS only**.
     *
     * @since 2.0.0
     */
    async setTitleBarStyle(style) {
      return invoke("plugin:window|set_title_bar_style", {
        label: this.label,
        value: style
      });
    }
    /**
     * Set window theme, pass in `null` or `undefined` to follow system theme
     *
     * #### Platform-specific
     *
     * - **Linux / macOS**: Theme is app-wide and not specific to this window.
     * - **iOS / Android:** Unsupported.
     *
     * @since 2.0.0
     */
    async setTheme(theme) {
      return invoke("plugin:window|set_theme", {
        label: this.label,
        value: theme
      });
    }
    // Listeners
    /**
     * Listen to window resize.
     *
     * @example
     * ```typescript
     * import { getCurrentWindow } from "@tauri-apps/api/window";
     * const unlisten = await getCurrentWindow().onResized(({ payload: size }) => {
     *  console.log('Window resized', size);
     * });
     *
     * // you need to call unlisten if your handler goes out of scope e.g. the component is unmounted
     * unlisten();
     * ```
     *
     * @returns A promise resolving to a function to unlisten to the event.
     * Note that removing the listener is required if your listener goes out of scope e.g. the component is unmounted.
     */
    async onResized(handler) {
      return this.listen(TauriEvent.WINDOW_RESIZED, (e) => {
        e.payload = new PhysicalSize(e.payload);
        handler(e);
      });
    }
    /**
     * Listen to window move.
     *
     * @example
     * ```typescript
     * import { getCurrentWindow } from "@tauri-apps/api/window";
     * const unlisten = await getCurrentWindow().onMoved(({ payload: position }) => {
     *  console.log('Window moved', position);
     * });
     *
     * // you need to call unlisten if your handler goes out of scope e.g. the component is unmounted
     * unlisten();
     * ```
     *
     * @returns A promise resolving to a function to unlisten to the event.
     * Note that removing the listener is required if your listener goes out of scope e.g. the component is unmounted.
     */
    async onMoved(handler) {
      return this.listen(TauriEvent.WINDOW_MOVED, (e) => {
        e.payload = new PhysicalPosition(e.payload);
        handler(e);
      });
    }
    /**
     * Listen to window close requested. Emitted when the user requests to closes the window.
     *
     * @example
     * ```typescript
     * import { getCurrentWindow } from "@tauri-apps/api/window";
     * import { confirm } from '@tauri-apps/api/dialog';
     * const unlisten = await getCurrentWindow().onCloseRequested(async (event) => {
     *   const confirmed = await confirm('Are you sure?');
     *   if (!confirmed) {
     *     // user did not confirm closing the window; let's prevent it
     *     event.preventDefault();
     *   }
     * });
     *
     * // you need to call unlisten if your handler goes out of scope e.g. the component is unmounted
     * unlisten();
     * ```
     *
     * @returns A promise resolving to a function to unlisten to the event.
     * Note that removing the listener is required if your listener goes out of scope e.g. the component is unmounted.
     */
    async onCloseRequested(handler) {
      return this.listen(TauriEvent.WINDOW_CLOSE_REQUESTED, async (event) => {
        const evt = new CloseRequestedEvent(event);
        await handler(evt);
        if (!evt.isPreventDefault()) {
          await this.destroy();
        }
      });
    }
    /**
     * Listen to a file drop event.
     * The listener is triggered when the user hovers the selected files on the webview,
     * drops the files or cancels the operation.
     *
     * @example
     * ```typescript
     * import { getCurrentWindow } from "@tauri-apps/api/webview";
     * const unlisten = await getCurrentWindow().onDragDropEvent((event) => {
     *  if (event.payload.type === 'over') {
     *    console.log('User hovering', event.payload.position);
     *  } else if (event.payload.type === 'drop') {
     *    console.log('User dropped', event.payload.paths);
     *  } else {
     *    console.log('File drop cancelled');
     *  }
     * });
     *
     * // you need to call unlisten if your handler goes out of scope e.g. the component is unmounted
     * unlisten();
     * ```
     *
     * @returns A promise resolving to a function to unlisten to the event.
     * Note that removing the listener is required if your listener goes out of scope e.g. the component is unmounted.
     */
    async onDragDropEvent(handler) {
      const unlistenDrag = await this.listen(TauriEvent.DRAG_ENTER, (event) => {
        handler({
          ...event,
          payload: {
            type: "enter",
            paths: event.payload.paths,
            position: new PhysicalPosition(event.payload.position)
          }
        });
      });
      const unlistenDragOver = await this.listen(TauriEvent.DRAG_OVER, (event) => {
        handler({
          ...event,
          payload: {
            type: "over",
            position: new PhysicalPosition(event.payload.position)
          }
        });
      });
      const unlistenDrop = await this.listen(TauriEvent.DRAG_DROP, (event) => {
        handler({
          ...event,
          payload: {
            type: "drop",
            paths: event.payload.paths,
            position: new PhysicalPosition(event.payload.position)
          }
        });
      });
      const unlistenCancel = await this.listen(TauriEvent.DRAG_LEAVE, (event) => {
        handler({ ...event, payload: { type: "leave" } });
      });
      return () => {
        unlistenDrag();
        unlistenDrop();
        unlistenDragOver();
        unlistenCancel();
      };
    }
    /**
     * Listen to window focus change.
     *
     * @example
     * ```typescript
     * import { getCurrentWindow } from "@tauri-apps/api/window";
     * const unlisten = await getCurrentWindow().onFocusChanged(({ payload: focused }) => {
     *  console.log('Focus changed, window is focused? ' + focused);
     * });
     *
     * // you need to call unlisten if your handler goes out of scope e.g. the component is unmounted
     * unlisten();
     * ```
     *
     * @returns A promise resolving to a function to unlisten to the event.
     * Note that removing the listener is required if your listener goes out of scope e.g. the component is unmounted.
     */
    async onFocusChanged(handler) {
      const unlistenFocus = await this.listen(TauriEvent.WINDOW_FOCUS, (event) => {
        handler({ ...event, payload: true });
      });
      const unlistenBlur = await this.listen(TauriEvent.WINDOW_BLUR, (event) => {
        handler({ ...event, payload: false });
      });
      return () => {
        unlistenFocus();
        unlistenBlur();
      };
    }
    /**
     * Listen to window scale change. Emitted when the window's scale factor has changed.
     * The following user actions can cause DPI changes:
     * - Changing the display's resolution.
     * - Changing the display's scale factor (e.g. in Control Panel on Windows).
     * - Moving the window to a display with a different scale factor.
     *
     * @example
     * ```typescript
     * import { getCurrentWindow } from "@tauri-apps/api/window";
     * const unlisten = await getCurrentWindow().onScaleChanged(({ payload }) => {
     *  console.log('Scale changed', payload.scaleFactor, payload.size);
     * });
     *
     * // you need to call unlisten if your handler goes out of scope e.g. the component is unmounted
     * unlisten();
     * ```
     *
     * @returns A promise resolving to a function to unlisten to the event.
     * Note that removing the listener is required if your listener goes out of scope e.g. the component is unmounted.
     */
    async onScaleChanged(handler) {
      return this.listen(TauriEvent.WINDOW_SCALE_FACTOR_CHANGED, handler);
    }
    /**
     * Listen to the system theme change.
     *
     * @example
     * ```typescript
     * import { getCurrentWindow } from "@tauri-apps/api/window";
     * const unlisten = await getCurrentWindow().onThemeChanged(({ payload: theme }) => {
     *  console.log('New theme: ' + theme);
     * });
     *
     * // you need to call unlisten if your handler goes out of scope e.g. the component is unmounted
     * unlisten();
     * ```
     *
     * @returns A promise resolving to a function to unlisten to the event.
     * Note that removing the listener is required if your listener goes out of scope e.g. the component is unmounted.
     */
    async onThemeChanged(handler) {
      return this.listen(TauriEvent.WINDOW_THEME_CHANGED, handler);
    }
  };
  var BackgroundThrottlingPolicy;
  (function(BackgroundThrottlingPolicy2) {
    BackgroundThrottlingPolicy2["Disabled"] = "disabled";
    BackgroundThrottlingPolicy2["Throttle"] = "throttle";
    BackgroundThrottlingPolicy2["Suspend"] = "suspend";
  })(BackgroundThrottlingPolicy || (BackgroundThrottlingPolicy = {}));
  var ScrollBarStyle;
  (function(ScrollBarStyle2) {
    ScrollBarStyle2["Default"] = "default";
    ScrollBarStyle2["FluentOverlay"] = "fluentOverlay";
  })(ScrollBarStyle || (ScrollBarStyle = {}));
  var Effect;
  (function(Effect2) {
    Effect2["AppearanceBased"] = "appearanceBased";
    Effect2["Light"] = "light";
    Effect2["Dark"] = "dark";
    Effect2["MediumLight"] = "mediumLight";
    Effect2["UltraDark"] = "ultraDark";
    Effect2["Titlebar"] = "titlebar";
    Effect2["Selection"] = "selection";
    Effect2["Menu"] = "menu";
    Effect2["Popover"] = "popover";
    Effect2["Sidebar"] = "sidebar";
    Effect2["HeaderView"] = "headerView";
    Effect2["Sheet"] = "sheet";
    Effect2["WindowBackground"] = "windowBackground";
    Effect2["HudWindow"] = "hudWindow";
    Effect2["FullScreenUI"] = "fullScreenUI";
    Effect2["Tooltip"] = "tooltip";
    Effect2["ContentBackground"] = "contentBackground";
    Effect2["UnderWindowBackground"] = "underWindowBackground";
    Effect2["UnderPageBackground"] = "underPageBackground";
    Effect2["Mica"] = "mica";
    Effect2["Blur"] = "blur";
    Effect2["Acrylic"] = "acrylic";
    Effect2["Tabbed"] = "tabbed";
    Effect2["TabbedDark"] = "tabbedDark";
    Effect2["TabbedLight"] = "tabbedLight";
  })(Effect || (Effect = {}));
  var EffectState;
  (function(EffectState2) {
    EffectState2["FollowsWindowActiveState"] = "followsWindowActiveState";
    EffectState2["Active"] = "active";
    EffectState2["Inactive"] = "inactive";
  })(EffectState || (EffectState = {}));

  // ../shared/desktop/main.js
  var $ = (id) => document.getElementById(id);
  var frame = $("editor-frame");
  var native = !!window.__TAURI_INTERNALS__;
  var basename = (path2) => path2.split(/[\\/]/).pop();
  var filters = [
    { name: "Markdown / \u7EAF\u6587\u672C", extensions: ["md", "markdown", "txt"] }
  ];
  var path = null;
  var name = "\u672A\u547D\u540D.md";
  var content = "";
  var saved = "";
  var ready = false;
  var busy = false;
  var source = false;
  var draftTimer;
  var initializedDocument;
  var foreground = !document.hidden;
  var nativeFocused = true;
  var pollTimer;
  var sleepTimer;
  var sleepingSession = null;
  var backgroundSleepDelay = 5 * 60 * 1e3;
  var settings = {
    theme: "system",
    fontSize: 16,
    showLineNumbers: false,
    typewriter: false
  };
  try {
    settings = {
      ...settings,
      ...JSON.parse(localStorage.getItem("mnotes.settings") || "{}")
    };
  } catch (_) {
  }
  try {
    const draft = JSON.parse(localStorage.getItem("mnotes.draft") || "null");
    if (draft && typeof draft.content === "string") {
      content = draft.content;
      name = typeof draft.name === "string" ? draft.name : name;
      saved = null;
      status("\u5DF2\u6062\u590D\u672A\u4FDD\u5B58\u7684\u8349\u7A3F\uFF0C\u8BF7\u53E6\u5B58\u4E3A\u6587\u4EF6\u3002");
    }
  } catch (_) {
  }
  $("platform").textContent = navigator.userAgent.includes("Windows") ? "Windows" : navigator.userAgent.includes("Linux") ? "Linux" : "Desktop";
  var editor = () => frame.contentWindow?.editor;
  var dirty = () => content !== saved;
  function status(message, error = false) {
    $("status").textContent = message;
    $("status").title = message;
    $("status").classList.toggle("error", error);
  }
  function persistDraft() {
    try {
      if (dirty())
        localStorage.setItem("mnotes.draft", JSON.stringify({ name, content }));
      else localStorage.removeItem("mnotes.draft");
    } catch (_) {
      status("\u65E0\u6CD5\u4FDD\u5B58\u6062\u590D\u8349\u7A3F\uFF0C\u8BF7\u53CA\u65F6\u4FDD\u5B58\u5230\u6587\u4EF6\u3002", true);
    }
  }
  function sync() {
    if (!ready) return;
    const next = editor().getContent();
    if (next !== content) {
      content = next;
      render();
      clearTimeout(draftTimer);
      draftTimer = setTimeout(persistDraft, 500);
    }
  }
  function render() {
    $("doc-title").textContent = `${dirty() ? "\u25CF " : ""}${name}`;
    $("doc-title").title = path || name;
    document.title = `${dirty() ? "\u25CF " : ""}${name} \u2014 M Notes`;
    $("save-state").textContent = !ready ? sleepingSession ? "\u540E\u53F0\u4F11\u7720\u4E2D" : "\u6B63\u5728\u52A0\u8F7D\u7F16\u8F91\u5668\u2026" : dirty() ? "\u6709\u672A\u4FDD\u5B58\u7684\u66F4\u6539" : "\u6240\u6709\u66F4\u6539\u5DF2\u4FDD\u5B58";
    $("file-type").textContent = /\.txt$/i.test(name) ? "\u7EAF\u6587\u672C" : "Markdown";
    $("statistics").textContent = `${Array.from(content.replace(/\s/g, "")).length.toLocaleString()} \u5B57\u7B26 \xB7 ${content.split("\n").length.toLocaleString()} \u884C`;
    const outline = $("outline");
    outline.replaceChildren();
    let count = 0, fence = null;
    if (!/\.txt$/i.test(name))
      content.split("\n").forEach((line, index) => {
        const marker = line.match(/^\s{0,3}(`{3,}|~{3,})/);
        if (marker) {
          if (!fence) fence = marker[1];
          else if (marker[1][0] === fence[0] && marker[1].length >= fence.length)
            fence = null;
          return;
        }
        const heading = !fence && line.match(/^\s{0,3}(#{1,6})\s+(.+?)\s*#*$/);
        if (!heading) return;
        const button = document.createElement("button");
        button.textContent = heading[2];
        button.style.paddingLeft = `${10 + (heading[1].length - 1) * 12}px`;
        button.onclick = () => editor()?.gotoLine(index + 1);
        outline.append(button);
        count++;
      });
    $("heading-count").textContent = count;
    if (!count) {
      const p = document.createElement("p");
      p.className = "empty";
      p.textContent = "\u6DFB\u52A0 Markdown \u6807\u9898\u540E\uFF0C\u5373\u53EF\u5728\u8FD9\u91CC\u5BFC\u822A\u3002";
      outline.append(p);
    }
    updateControls();
  }
  function updateControls() {
    document.querySelectorAll("nav button, #formatbar button").forEach((button) => {
      button.disabled = busy || !ready;
    });
    if (/\.txt$/i.test(name))
      document.querySelectorAll("#formatbar button, #btn-source").forEach((button) => {
        button.disabled = true;
      });
  }
  function applySettings() {
    const dark = ["github-dark", "liquid-glass-dark", "dracula"].includes(settings.theme) || settings.theme === "system" && matchMedia("(prefers-color-scheme: dark)").matches;
    document.documentElement.dataset.dark = dark;
    if (ready) {
      editor().setTheme(settings.theme);
      editor().setPreferences(settings);
      editor().setTypewriterMode(settings.typewriter);
    }
    try {
      localStorage.setItem("mnotes.settings", JSON.stringify(settings));
    } catch (_) {
    }
  }
  async function initialize() {
    if (frame.getAttribute("src") === "about:blank") return;
    const doc = frame.contentDocument;
    if (initializedDocument === doc) return;
    initializedDocument = doc;
    doc.addEventListener("keydown", shortcuts, true);
    for (let i = 0; i < 100; i++) {
      if (frame.contentDocument !== doc) return;
      if (editor()?._view) {
        ready = true;
        editor().setBackgrounded(!foreground);
        editor().openDocument(
          content,
          sleepingSession ? JSON.parse(sleepingSession).documentID : `${Date.now()}`,
          {},
          /\.txt$/i.test(name)
        );
        editor().setLanguage("zh-Hans");
        editor().setSourceMode(source);
        applySettings();
        if (sleepingSession) {
          try {
            editor().restoreSession(sleepingSession);
          } catch (error) {
            status(`\u6062\u590D\u64A4\u9500\u8BB0\u5F55\u5931\u8D25\uFF1A${error.message}`, true);
          }
          sleepingSession = null;
        }
        editor().setBackgrounded(!foreground);
        if (!$("searchbar").hidden) search();
        render();
        return;
      }
      await new Promise((resolve) => setTimeout(resolve, 50));
    }
    status("\u7F16\u8F91\u5668\u52A0\u8F7D\u5931\u8D25\uFF0C\u8BF7\u91CD\u65B0\u542F\u52A8\u5E94\u7528\u3002\u6062\u590D\u8349\u7A3F\u5DF2\u4FDD\u7559\u3002", true);
  }
  frame.addEventListener("load", initialize);
  if (frame.contentDocument?.readyState === "complete") initialize();
  function replaceDocument(text, filePath, fileName) {
    sleepingSession = null;
    content = saved = text;
    path = filePath;
    name = fileName;
    ready = false;
    source = false;
    $("btn-source").setAttribute("aria-pressed", "false");
    $("searchbar").hidden = true;
    $("query").value = "";
    $("replacement").value = "";
    persistDraft();
    render();
    frame.src = "editor/editor.html";
  }
  function askUnsaved() {
    const dialog = $("unsaved");
    $("unsaved-description").textContent = `\u201C${name}\u201D\u6709\u672A\u4FDD\u5B58\u7684\u66F4\u6539\u3002`;
    return new Promise((resolve) => {
      dialog.returnValue = "cancel";
      dialog.addEventListener("close", () => resolve(dialog.returnValue), {
        once: true
      });
      dialog.showModal();
    });
  }
  async function allowDiscard() {
    sync();
    if (!dirty()) return true;
    const answer = await askUnsaved();
    return answer === "discard" || answer === "save" && await saveDocument(false) && !dirty();
  }
  async function action(fn, allowLoading = false) {
    if (busy || !ready && !allowLoading) return;
    busy = true;
    updateControls();
    try {
      await fn();
    } catch (error) {
      status(`\u64CD\u4F5C\u5931\u8D25\uFF1A${error.message || error}`, true);
    } finally {
      busy = false;
      updateControls();
    }
  }
  async function saveDocument(saveAs) {
    sync();
    const snapshot = content;
    let destination = path;
    if (native) {
      if (saveAs || !destination)
        destination = await save({ defaultPath: path || name, filters });
      if (!destination) return false;
      await writeTextFile(destination, snapshot);
      path = destination;
      name = basename(destination);
    } else {
      const link = document.createElement("a");
      const url = URL.createObjectURL(
        new Blob([snapshot], { type: "text/plain;charset=utf-8" })
      );
      link.href = url;
      link.download = name;
      link.click();
      setTimeout(() => URL.revokeObjectURL(url), 1e3);
    }
    saved = snapshot;
    sync();
    persistDraft();
    render();
    editor()?.openDocument(
      content,
      editor().documentID,
      {
        anchor: editor()._view.state.selection.main.head,
        scrollTop: editor()._view.scrollDOM.scrollTop
      },
      /\.txt$/i.test(name)
    );
    editor()?.setSourceMode(source);
    status(native ? "\u6587\u6863\u5DF2\u4FDD\u5B58" : "\u5DF2\u751F\u6210\u4E0B\u8F7D\u6587\u4EF6\uFF0C\u8BF7\u786E\u8BA4\u6D4F\u89C8\u5668\u4E0B\u8F7D\u5B8C\u6210");
    return true;
  }
  async function openDocument() {
    if (native) {
      const selected = await open({ multiple: false, filters });
      if (!selected) return;
      const text = await readTextFile(selected);
      if (await allowDiscard()) {
        replaceDocument(text, selected, basename(selected));
        status("\u6587\u6863\u5DF2\u6253\u5F00");
      }
    } else {
      const input = document.createElement("input");
      input.type = "file";
      input.accept = ".md,.markdown,.txt";
      input.onchange = () => action(async () => {
        const file = input.files[0];
        if (!file) return;
        const text = await file.text();
        if (await allowDiscard()) replaceDocument(text, null, file.name);
      });
      input.click();
    }
  }
  function toggleSearch(show = $("searchbar").hidden) {
    $("searchbar").hidden = !show;
    if (show) {
      $("query").focus();
      $("query").select();
    } else {
      editor()?.execCommand("find:");
      editor()?._view.focus();
    }
  }
  function search(command) {
    editor()?.execCommand(
      `findWithOptions:${JSON.stringify({ query: $("query").value, replace: $("replacement").value, caseSensitive: $("match-case").checked, regexp: false })}`
    );
    if (command) editor()?.execCommand(command);
  }
  function shortcuts(event) {
    if (!(event.ctrlKey || event.metaKey) || event.altKey || $("unsaved").open || $("settings").open)
      return;
    const key = event.key.toLowerCase();
    const operations = {
      s: () => action(() => saveDocument(event.shiftKey)),
      o: () => action(openDocument),
      n: () => action(async () => {
        if (await allowDiscard()) replaceDocument("", null, "\u672A\u547D\u540D.md");
      }),
      f: () => toggleSearch(true),
      h: () => toggleSearch(true),
      "\\": () => $("btn-sidebar").click()
    };
    if (operations[key]) {
      event.preventDefault();
      event.stopPropagation();
      if (ready && !busy) operations[key]();
    }
  }
  window.addEventListener("keydown", shortcuts, true);
  $("btn-new").onclick = () => action(async () => {
    if (await allowDiscard()) replaceDocument("", null, "\u672A\u547D\u540D.md");
  });
  $("btn-open").onclick = () => action(openDocument);
  $("btn-save").onclick = () => action(() => saveDocument(false));
  $("btn-save-as").onclick = () => action(() => saveDocument(true));
  $("btn-sidebar").onclick = () => {
    $("sidebar").hidden = !$("sidebar").hidden;
    $("btn-sidebar").setAttribute("aria-expanded", String(!$("sidebar").hidden));
  };
  $("btn-source").onclick = () => {
    source = !source;
    editor().setSourceMode(source);
    $("btn-source").setAttribute("aria-pressed", String(source));
  };
  $("btn-search").onclick = () => toggleSearch();
  $("close-search").onclick = () => toggleSearch(false);
  $("searchbar").onkeydown = (event) => {
    if (event.key === "Escape") toggleSearch(false);
    if (event.key === "Enter") {
      event.preventDefault();
      search(event.shiftKey ? "findPrev" : "findNext");
    }
  };
  ["query", "replacement", "match-case"].forEach(
    (id) => $(id).addEventListener("input", () => search())
  );
  document.querySelectorAll("[data-search]").forEach((button) => {
    button.onclick = () => search(button.dataset.search);
  });
  document.querySelectorAll("[data-command]").forEach((button) => {
    button.onmousedown = (event) => event.preventDefault();
    button.onclick = () => {
      editor()?.execCommand(button.dataset.command);
      editor()?._view.focus();
      sync();
    };
  });
  async function insertImage(file) {
    const dataURL = await new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => resolve(reader.result);
      reader.onerror = () => reject(reader.error);
      reader.readAsDataURL(file);
    });
    editor().insertAtCursor(`![\u56FE\u7247](${dataURL})`);
    sync();
  }
  $("btn-image").onclick = () => action(async () => {
    if (native) {
      const selected = await open({
        multiple: false,
        filters: [
          { name: "\u56FE\u7247", extensions: ["png", "jpg", "jpeg", "gif", "webp"] }
        ]
      });
      if (!selected) return;
      const extension = selected.split(".").pop().toLowerCase();
      const mime = extension === "jpg" ? "jpeg" : extension;
      await insertImage(
        new Blob([await readFile(selected)], { type: `image/${mime}` })
      );
    } else {
      const input = document.createElement("input");
      input.type = "file";
      input.accept = "image/png,image/jpeg,image/gif,image/webp";
      input.onchange = () => action(async () => {
        if (input.files[0]) await insertImage(input.files[0]);
      });
      input.click();
    }
  });
  $("btn-export").onclick = () => action(async () => {
    sync();
    const exported = await editor().getExportDocument();
    const doc = new DOMParser().parseFromString(exported.html, "text/html");
    for (const image of exported.images) {
      const element = doc.querySelector(`img[src="${image.token}"]`);
      if (element && /^(https?:|data:image\/)/i.test(image.src || ""))
        element.setAttribute("src", image.src);
      else if (element) {
        element.removeAttribute("src");
        element.alt = `\u56FE\u7247\u672A\u5D4C\u5165\uFF1A${image.src || ""}`;
      }
    }
    const html = "<!doctype html>\n" + doc.documentElement.outerHTML;
    const exportName = name.replace(/\.[^.]+$/, "") + ".html";
    if (native) {
      const destination = await save({
        defaultPath: exportName,
        filters: [{ name: "HTML", extensions: ["html"] }]
      });
      if (!destination) return;
      await writeTextFile(destination, html);
    } else {
      const url = URL.createObjectURL(
        new Blob([html], { type: "text/html;charset=utf-8" })
      );
      const link = document.createElement("a");
      link.href = url;
      link.download = exportName;
      link.click();
      setTimeout(() => URL.revokeObjectURL(url), 1e3);
    }
    status("HTML \u5DF2\u5BFC\u51FA\uFF1B\u76F8\u5BF9\u8DEF\u5F84\u56FE\u7247\u9700\u5148\u4F7F\u7528\u201C\u56FE\u7247\u201D\u6309\u94AE\u5D4C\u5165\u3002");
  });
  $("btn-settings").onclick = () => $("settings").showModal();
  $("theme").value = settings.theme;
  $("font-size").value = settings.fontSize;
  $("line-numbers").checked = settings.showLineNumbers;
  $("typewriter").checked = settings.typewriter;
  $("settings").onchange = () => {
    settings = {
      theme: $("theme").value,
      fontSize: Number($("font-size").value),
      showLineNumbers: $("line-numbers").checked,
      typewriter: $("typewriter").checked
    };
    applySettings();
  };
  matchMedia("(prefers-color-scheme: dark)").addEventListener(
    "change",
    applySettings
  );
  window.addEventListener("beforeunload", (event) => {
    sync();
    persistDraft();
    if (!native && dirty()) {
      event.preventDefault();
      event.returnValue = "";
    }
  });
  if (native)
    getCurrentWindow().onCloseRequested(async (event) => {
      event.preventDefault();
      await action(async () => {
        if (await allowDiscard()) {
          clearTimeout(draftTimer);
          localStorage.removeItem("mnotes.draft");
          await getCurrentWindow().destroy();
        }
      }, true);
    }).catch((error) => status(`\u65E0\u6CD5\u542F\u7528\u5173\u95ED\u4FDD\u62A4\uFF1A${error}`, true));
  function hibernateEditor() {
    if (foreground || sleepingSession) return;
    if (busy || !ready || $("unsaved").open) {
      sleepTimer = setTimeout(hibernateEditor, 6e4);
      return;
    }
    try {
      const snapshot = editor().captureSession();
      if (!snapshot) {
        sleepTimer = setTimeout(hibernateEditor, 6e4);
        return;
      }
      sync();
      clearTimeout(draftTimer);
      persistDraft();
      sleepingSession = snapshot;
      ready = false;
      frame.src = "about:blank";
      status("\u540E\u53F0\u4F11\u7720\u4E2D\uFF0C\u8FD4\u56DE\u540E\u81EA\u52A8\u6062\u590D");
      render();
    } catch (error) {
      status(`\u6682\u672A\u8FDB\u5165\u4F11\u7720\uFF1A${error.message}`, true);
    }
  }
  function setActivity(active) {
    const wasForeground = foreground;
    foreground = active;
    clearInterval(pollTimer);
    pollTimer = null;
    clearTimeout(sleepTimer);
    sleepTimer = null;
    if (active) {
      if (sleepingSession) frame.src = "editor/editor.html";
      else editor()?.setBackgrounded(false);
      pollTimer = setInterval(sync, 250);
      if (!wasForeground) status("\u5DF2\u8FD4\u56DE\u524D\u53F0");
    } else {
      sync();
      clearTimeout(draftTimer);
      persistDraft();
      editor()?.setBackgrounded(true);
      if (!sleepingSession)
        sleepTimer = setTimeout(hibernateEditor, backgroundSleepDelay);
    }
  }
  document.addEventListener(
    "visibilitychange",
    () => setActivity(!document.hidden && nativeFocused)
  );
  if (native)
    getCurrentWindow().onFocusChanged(({ payload }) => {
      nativeFocused = payload;
      setActivity(payload && !document.hidden);
    }).catch((error) => status(`\u540E\u53F0\u8282\u80FD\u76D1\u542C\u5931\u8D25\uFF1A${error}`, true));
  setActivity(foreground);
  applySettings();
  render();
})();
