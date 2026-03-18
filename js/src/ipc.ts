type Handler = (buffer: ArrayBuffer) => void;

const _handlers: Record<string, Handler[]> = {};
const _scheme = "ipc";

function _openStream(channel: string): void {
    const xhr = new XMLHttpRequest();
    xhr.open("GET", `${_scheme}://app/ipc/stream/${channel}`, true);
    xhr.overrideMimeType("text/plain; charset=x-user-defined");

    let pos = 0;
    xhr.onprogress = () => {
        const chunk = xhr.responseText.slice(pos);
        pos = xhr.responseText.length;

        const buf = new Uint8Array(chunk.length);
        for (let i = 0; i < chunk.length; i++)
            buf[i] = chunk.charCodeAt(i) & 0xff;

        (_handlers[channel] ?? []).forEach(cb => cb(buf.buffer));
    };

    xhr.onerror   = () => setTimeout(() => _openStream(channel), 500);
    xhr.onloadend = () => setTimeout(() => _openStream(channel), 500);
    xhr.send();
}

const ipc = {
    send(channel: string, buffer: ArrayBuffer): void {
        fetch(`${_scheme}://app/ipc/send/${channel}`, {
            method: "POST",
            body:   buffer
        }).catch(e => console.error("[ipc] send error", e));
    },

    on(channel: string, callback: Handler): void {
        if (!_handlers[channel]) {
            _handlers[channel] = [];
            _openStream(channel);
        }
        _handlers[channel].push(callback);
    }
};

export default ipc;
export type { Handler };