import Toybox.Graphics;
import Toybox.Lang;
import Toybox.Math;
import Toybox.System;
import Toybox.WatchUi;

//! FORK: full text of the long prayers (Věřím v Boha, Zdrávas Královno, Modleme se),
//! shown page by page. Opened automatically when the rosary reaches such a prayer.
//! Tap / START continues with the next prayer, BACK only closes the text.
class PrayerTextView extends WatchUi.View {

    private const TITLE_FONT = Graphics.FONT_TINY;
    private const BODY_FONT = Graphics.FONT_XTINY;
    private const HINT_FONT = Graphics.FONT_XTINY;

    private var _title as String;
    private var _text as String;

    private var _pages as Array<Array<String> > = [];
    private var _page as Number = 0;
    private var _lineHeight as Number = 20;

    private var _titleY as Number = 0;
    private var _bodyTop as Number = 0;
    private var _hintY as Number = 0;

    private var _colorGold as Number = 0xFFD700;
    private var _colorTextDim as Number = 0xAAAAAA;

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

        _lineHeight = dc.getFontHeight(BODY_FONT);
        _titleY = isRound ? (height * 0.07).toNumber() : 4;
        _bodyTop = _titleY + dc.getFontHeight(TITLE_FONT) + 8;
        _hintY = height - (isRound ? (height * 0.05).toNumber() : 2) - dc.getFontHeight(HINT_FONT);

        var rows = (_hintY - 2 - _bodyTop) / _lineHeight;
        if (rows < 1) {
            rows = 1;
        }

        // Width of each row: on a round screen, the chord at the row's edge farthest from the center
        var rowWidths = [] as Array<Number>;
        var radius = width / 2.0;
        var centerY = height / 2;
        for (var r = 0; r < rows; r++) {
            var rowWidth = width * 0.92;
            if (isRound) {
                var dy = (_bodyTop + r * _lineHeight - centerY).abs();
                var dyBottom = (_bodyTop + (r + 1) * _lineHeight - centerY).abs();
                if (dyBottom > dy) {
                    dy = dyBottom;
                }
                rowWidth = (dy < radius) ? 2 * Math.sqrt(radius * radius - dy * dy) * 0.92 : width * 0.5;
            }
            rowWidths.add(rowWidth.toNumber());
        }

        _pages = layoutPages(dc, _text, rowWidths);
        if (_page >= _pages.size()) {
            _page = 0;
        }
    }

    function onUpdate(dc as Dc) as Void {
        var centerX = dc.getWidth() / 2;

        dc.setColor(Graphics.COLOR_BLACK, Graphics.COLOR_BLACK);
        dc.clear();

        dc.setColor(_colorGold, Graphics.COLOR_TRANSPARENT);
        dc.drawText(centerX, _titleY, TITLE_FONT, _title, Graphics.TEXT_JUSTIFY_CENTER);

        // Rule under the title, or an up arrow when there are previous pages
        var markY = _bodyTop - 5;
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
    private function layoutPages(dc as Dc, text as String, rowWidths as Array<Number>) as Array<Array<String> > {
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
        var halfSize = 5;
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
