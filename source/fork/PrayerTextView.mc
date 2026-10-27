import Toybox.Attention;
import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.Timer;
import Toybox.WatchUi;

//! FORK: full text of the long prayers (Věřím v Boha, Zdrávas Královno, Modleme se),
//! shown page by page. Opened automatically when the rosary reaches such a prayer.
//! Tap / START continues with the next prayer, BACK only closes the text.
//! The backlight is kept on while the text is shown, so it can be read to the end in the dark.
class PrayerTextView extends WatchUi.View {

    private const TITLE_FONT = Graphics.FONT_TINY;
    private const BODY_FONT = Graphics.FONT_XTINY;
    private const HINT_FONT = Graphics.FONT_XTINY;

    //! A last page with at most this many lines is a stub: the layout is tightened to avoid it.
    private const STUB_LINES = 2;

    //! The display is re-lit this often; devices time the backlight out by themselves
    private const BACKLIGHT_REFRESH_MS = 2000;
    //! ... and for at most this long, so a forgotten text view does not drain the battery
    private const BACKLIGHT_MAX_MS = 180000;

    private var _title as String;
    private var _text as String;

    private var _pages as Array<Array<String> > = [];
    private var _page as Number = 0;
    private var _lineHeight as Number = 20;

    private var _titleY as Number = 0;
    private var _titleBottom as Number = 0;
    private var _bodyTop as Number = 0;
    private var _hintY as Number = 0;

    private var _colorGold as Number = 0xFFD700;
    private var _colorTextDim as Number = 0xAAAAAA;

    private var _backlightTimer as Timer.Timer? = null;
    private var _backlightElapsedMs as Number = 0;

    //! Resource of the full text for a rosary state, null when the state has none.
    static function getTextId(state as Number) as ResourceId? {
        switch (state) {
            case RosaryModel.STATE_CREED: return Rez.Strings.prayer_creed_text;
            case RosaryModel.STATE_SALVE: return Rez.Strings.prayer_salve_text;
            case RosaryModel.STATE_ORATIO: return Rez.Strings.prayer_oratio_text;
            default: return null;
        }
    }

    private static function getTitleId(state as Number) as ResourceId {
        switch (state) {
            case RosaryModel.STATE_SALVE: return Rez.Strings.prayer_salve;
            case RosaryModel.STATE_ORATIO: return Rez.Strings.prayer_oratio;
            default: return Rez.Strings.prayer_creed;
        }
    }

    function initialize(state as Number) {
        View.initialize();
        _title = WatchUi.loadResource(getTitleId(state)) as String;
        var textId = getTextId(state);
        _text = (textId != null) ? WatchUi.loadResource(textId) as String : "";
    }

    function onLayout(dc as Dc) as Void {
        var width = dc.getWidth();
        var height = dc.getHeight();
        var isRound = (System.getDeviceSettings().screenShape == System.SCREEN_SHAPE_ROUND);

        if ((width <= 176 && height <= 176) || ((dc has :getColorDepth) && dc.getColorDepth() <= 2)) {
            _colorGold = Graphics.COLOR_WHITE;
            _colorTextDim = Graphics.COLOR_WHITE;
        }

        _titleY = isRound ? (height * 0.07).toNumber() : 4;
        _titleBottom = _titleY + dc.getFontHeight(TITLE_FONT);
        _hintY = height - (isRound ? (height * 0.05).toNumber() : 2) - dc.getFontHeight(HINT_FONT);

        // Settings tried in order: [line spacing reduction (px), row width factor, gap under the title (px)].
        // The first one is the comfortable layout; the others are used only when it leaves a stub
        // of one or two lines on the last page, which would cost a whole extra scroll.
        var attempts = [[0, 0.92, 8], [0, 0.97, 8], [2, 0.97, 6], [3, 0.97, 6]];
        var bodyHeight = dc.getFontHeight(BODY_FONT);

        var best = layoutPages(dc, bodyHeight, isRound, attempts[0]);
        var bestPages = best[:pages] as Array<Array<String> >;
        if (bestPages.size() > 1 && bestPages[bestPages.size() - 1].size() <= STUB_LINES) {
            for (var i = 1; i < attempts.size(); i++) {
                var candidate = layoutPages(dc, bodyHeight, isRound, attempts[i]);
                if ((candidate[:pages] as Array).size() < bestPages.size()) {
                    best = candidate;
                    break;
                }
            }
        }

        _pages = best[:pages] as Array<Array<String> >;
        _lineHeight = best[:lineHeight] as Number;
        _bodyTop = best[:bodyTop] as Number;
        if (_page >= _pages.size()) {
            _page = 0;
        }
    }

    //! Pages of text for the given settings, with the line height and top of the text they imply:
    //! {:pages, :lineHeight, :bodyTop}.
    private function layoutPages(dc as Dc, fontHeight as Number, isRound as Boolean, attempt as Array<Number or Float>) as Dictionary {
        var tighten = attempt[0] as Number;
        var widthFactor = attempt[1] as Float;
        var gap = attempt[2] as Number;

        var lineHeight = fontHeight - tighten;
        var bodyTop = _titleBottom + gap;
        var rows = (_hintY - 2 - bodyTop) / lineHeight;
        if (rows < 1) {
            rows = 1;
        }

        // Width of each row: on a round screen, the chord at the row's edge farthest from the center
        var width = dc.getWidth();
        var radius = width / 2.0;
        var centerY = dc.getHeight() / 2;
        var rowWidths = [] as Array<Number>;
        for (var r = 0; r < rows; r++) {
            var rowWidth = width * widthFactor;
            if (isRound) {
                var dy = (bodyTop + r * lineHeight - centerY).abs();
                var dyBottom = (bodyTop + (r + 1) * lineHeight - centerY).abs();
                if (dyBottom > dy) {
                    dy = dyBottom;
                }
                rowWidth = (dy < radius) ? 2 * Math.sqrt(radius * radius - dy * dy) * widthFactor : width * 0.5;
            }
            rowWidths.add(rowWidth.toNumber());
        }

        return {:pages => splitIntoPages(dc, _text, rowWidths), :lineHeight => lineHeight, :bodyTop => bodyTop};
    }

    function onShow() as Void {
        _backlightElapsedMs = 0;
        keepBacklightOn();
        if (_backlightTimer == null) {
            _backlightTimer = new Timer.Timer();
        }
        stopBacklightTimer();
        (_backlightTimer as Timer.Timer).start(method(:keepBacklightOn), BACKLIGHT_REFRESH_MS, true);
    }

    function onHide() as Void {
        stopBacklightTimer();
    }

    //! Public: called by the timer
    function keepBacklightOn() as Void {
        if (_backlightElapsedMs >= BACKLIGHT_MAX_MS || !(Attention has :backlight)) {
            stopBacklightTimer();
            return;
        }
        _backlightElapsedMs += BACKLIGHT_REFRESH_MS;
        try {
            Attention.backlight(true);
        } catch (ex) {
            // Devices with burn-in protection refuse to hold the display on for long
            stopBacklightTimer();
        }
    }

    private function stopBacklightTimer() as Void {
        if (_backlightTimer != null) {
            (_backlightTimer as Timer.Timer).stop();
        }
    }

    function onUpdate(dc as Dc) as Void {
        var centerX = dc.getWidth() / 2;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        dc.setColor(_colorGold, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, _titleY, TITLE_FONT, _title, Graphics.TEXT_JUSTIFY_CENTER);

        // Rule under the title, or an up arrow when there are previous pages
        var markY = _titleBottom + 3;
        if (_page > 0) {
            drawTriangle(dc, centerX, markY, true);
        } else {
            dc.setPenWidth(1);
            dc.drawLine(centerX - 22, markY, centerX + 22, markY);
        }

        if (_pages.size() > 0) {
            dc.setColor(Graphics.COLOR_WHITE, Graphics.COLOR_TRANSPARENT);
            var lines = _pages[_page];
            for (var i = 0; i < lines.size(); i++) {
                dc.drawText(centerX, _bodyTop + i * _lineHeight, BODY_FONT, lines[i], Graphics.TEXT_JUSTIFY_CENTER);
            }
        }

        dc.setColor(_colorTextDim, Graphics.COLOR_TRANSPARENT);
        if (canScrollDown()) {
            drawTriangle(dc, centerX, _hintY + dc.getFontHeight(HINT_FONT) / 2, false);
        } else {
            var hint = WatchUi.loadResource(Rez.Strings.hint_continue) as String;
            dc.drawText(centerX, _hintY, HINT_FONT, hint, Graphics.TEXT_JUSTIFY_CENTER);
        }
    }

    //! Number of lines on each page (used by the tests)
    function getPageSizes() as Array<Number> {
        var sizes = [] as Array<Number>;
        for (var i = 0; i < _pages.size(); i++) {
            sizes.add(_pages[i].size());
        }
        return sizes;
    }

    private function canScrollDown() as Boolean {
        return _page < _pages.size() - 1;
    }

    function scrollDown() as Boolean {
        if (!canScrollDown()) {
            return false;
        }
        _page++;
        WatchUi.requestUpdate();
        return true;
    }

    function scrollUp() as Boolean {
        if (_page <= 0) {
            return false;
        }
        _page--;
        WatchUi.requestUpdate();
        return true;
    }

    //! One source line = one phrase, starting a new row; phrases that do not fit the row
    //! are wrapped at spaces. Rows fill a page, then continue on the next one.
    private function splitIntoPages(dc as Dc, text as String, rowWidths as Array<Number>) as Array<Array<String> > {
        var pages = [] as Array<Array<String> >;
        var page = [] as Array<String>;
        var paragraphs = split(text, "\n");
        for (var p = 0; p < paragraphs.size(); p++) {
            var words = split(stripCarriageReturns(paragraphs[p]), " ");
            var current = "";
            for (var i = 0; i < words.size(); i++) {
                var candidate = (current.length() == 0) ? words[i] : current + " " + words[i];
                if (current.length() > 0 && dc.getTextWidthInPixels(candidate, BODY_FONT) > rowWidths[page.size()]) {
                    page.add(current);
                    if (page.size() == rowWidths.size()) {
                        pages.add(page);
                        page = [] as Array<String>;
                    }
                    current = words[i];
                } else {
                    current = candidate;
                }
            }
            if (current.length() > 0) {
                page.add(current);
                if (page.size() == rowWidths.size()) {
                    pages.add(page);
                    page = [] as Array<String>;
                }
            }
        }
        if (page.size() > 0) {
            pages.add(page);
        }
        return pages;
    }

    private function stripCarriageReturns(str as String) as String {
        var parts = split(str, "\r");
        var result = "";
        for (var i = 0; i < parts.size(); i++) {
            result += parts[i];
        }
        return result;
    }

    //! Splits on the delimiter, dropping empty parts
    private function split(str as String, delimiter as String) as Array<String> {
        var result = [] as Array<String>;
        var current = str;
        var index = current.find(delimiter);
        while (index != null) {
            if (index > 0) {
                result.add(current.substring(0, index) as String);
            }
            current = current.substring(index + delimiter.length(), current.length()) as String;
            index = current.find(delimiter);
        }
        if (current.length() > 0) {
            result.add(current);
        }
        return result;
    }

    private function drawTriangle(dc as Dc, x as Number, centerY as Number, pointingUp as Boolean) as Void {
        var halfSize = 4;
        var baseY = centerY + (pointingUp ? halfSize : -halfSize);
        var tipY = centerY + (pointingUp ? -halfSize : halfSize);
        dc.fillPolygon([[x - halfSize, baseY], [x + halfSize, baseY], [x, tipY]]);
    }
}

//! FORK: input for the full-text view
class PrayerTextDelegate extends WatchUi.BehaviorDelegate {

    private var _view as PrayerTextView;
    private var _onContinue as Method() as Void;
    private var _lastDragY as Number = 0;

    function initialize(view as PrayerTextView, onContinue as Method() as Void) {
        BehaviorDelegate.initialize();
        _view = view;
        _onContinue = onContinue;
    }

    //! Closes the text and moves on to the next prayer
    private function continuePrayer() as Void {
        WatchUi.popView(WatchUi.SLIDE_IMMEDIATE);
        _onContinue.invoke();
    }

    function onTap(clickEvent as WatchUi.ClickEvent) as Boolean {
        continuePrayer();
        return true;
    }

    function onKey(keyEvent as WatchUi.KeyEvent) as Boolean {
        var key = keyEvent.getKey();
        if (key == WatchUi.KEY_DOWN) {
            _view.scrollDown();
            return true;
        } else if (key == WatchUi.KEY_UP) {
            _view.scrollUp();
            return true;
        } else if (key == WatchUi.KEY_ENTER || key == WatchUi.KEY_START) {
            continuePrayer();
            return true;
        }
        return false;
    }

    function onSwipe(swipeEvent as WatchUi.SwipeEvent) as Boolean {
        var direction = swipeEvent.getDirection();
        if (direction == WatchUi.SWIPE_UP) {
            _view.scrollDown();
            return true;
        } else if (direction == WatchUi.SWIPE_DOWN) {
            _view.scrollUp();
            return true;
        } else if (direction == WatchUi.SWIPE_RIGHT) {
            WatchUi.popView(WatchUi.SLIDE_RIGHT);
            return true;
        }
        return false;
    }

    function onDrag(dragEvent as WatchUi.DragEvent) as Boolean {
        var type = dragEvent.getType();
        var y = dragEvent.getCoordinates()[1];
        if (type == WatchUi.DRAG_TYPE_START) {
            _lastDragY = y;
            return true;
        } else if (type == WatchUi.DRAG_TYPE_CONTINUE) {
            var delta = y - _lastDragY;
            if (delta < -30 && _view.scrollDown()) {
                _lastDragY = y;
            } else if (delta > 30 && _view.scrollUp()) {
                _lastDragY = y;
            }
            return true;
        }
        return false;
    }

    function onNextPage() as Boolean {
        _view.scrollDown();
        return true;
    }

    function onPreviousPage() as Boolean {
        _view.scrollUp();
        return true;
    }

    function onBack() as Boolean {
        WatchUi.popView(WatchUi.SLIDE_RIGHT);
        return true;
    }
}
