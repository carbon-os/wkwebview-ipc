const _handlers = {};
const _scheme   = "ipc";

function _openStream(channel) {
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

        (_handlers[channel] || []).forEach(cb => cb(buf.buffer));
    };

    // auto-reconnect
    xhr.onerror   = () => setTimeout(() => _openStream(channel), 500);
    xhr.onloadend = () => setTimeout(() => _openStream(channel), 500);
    xhr.send();
}

const ipc = {
    send(channel, buffer) {
        fetch(`${_scheme}://app/ipc/send/${channel}`, {
            method: "POST",
            body:   buffer instanceof ArrayBuffer ? buffer : new Uint8Array(buffer)
        }).catch(e => console.error("[ipc] send error", e));
    },

    on(channel, callback) {
        if (!_handlers[channel]) {
            _handlers[channel] = [];
            _openStream(channel);
        }
        _handlers[channel].push(callback);
    }
};

window.ipc = ipc;
export default ipc;