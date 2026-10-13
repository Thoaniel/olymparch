// A small line chart for a Dropdown row: the last values (oldest first) scaled to [0, max], a faint fill under the
// line and the newest point marked. Used by the System panel for CPU, GPU, memory and temperature.
import QtQuick

Canvas {
    id: c
    required property var theme
    property var values: []
    property real max: 100
    property color tint: theme.gold
    width: theme.px(110)
    height: theme.px(22)
    onValuesChanged: requestPaint()
    onTintChanged: requestPaint()
    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const v = values, n = v.length;
        if (n < 2) return;
        const step = width / (Math.max(n, 30) - 1), x0 = width - (n - 1) * step;
        const y = val => height - 2 - (height - 4) * Math.max(0, Math.min(1, val / c.max));
        ctx.beginPath();
        ctx.moveTo(x0, height);
        for (let i = 0; i < n; i++) ctx.lineTo(x0 + i * step, y(v[i]));
        ctx.lineTo(x0 + (n - 1) * step, height);
        ctx.closePath();
        ctx.fillStyle = Qt.rgba(c.tint.r, c.tint.g, c.tint.b, 0.15);
        ctx.fill();
        ctx.beginPath();
        for (let i = 0; i < n; i++) { const px = x0 + i * step, py = y(v[i]); if (i === 0) ctx.moveTo(px, py); else ctx.lineTo(px, py); }
        ctx.strokeStyle = c.tint;
        ctx.lineWidth = 1.5;
        ctx.stroke();
        ctx.fillStyle = c.tint;
        ctx.fillRect(width - 3, y(v[n - 1]) - 1.5, 3, 3);
    }
}
