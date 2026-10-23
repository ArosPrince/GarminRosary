import Toybox.Graphics;
import Toybox.Lang;

//! FORK: upstream MeditationView.mc (commit 84f12c8) references DeviceProfile, Palette
//! and RosaryConstants, which were never committed to the upstream repository, so HEAD
//! does not compile. These minimal stand-ins reproduce the heuristics still used by
//! GarminRosaryView (shape, Instinct, monochrome). Delete this file once upstream
//! publishes the real classes (the compiler will then report duplicate definitions).

module RosaryConstants {
    const SHAPE_ROUND = 0;
    const SHAPE_RECTANGLE = 1;
}

class DeviceProfile {
    var shape as Number = RosaryConstants.SHAPE_ROUND;
    var isInstinct as Boolean = false;
    var isMonochrome as Boolean = false;

    static function fromSystem(dc as Dc) as DeviceProfile {
        var profile = new DeviceProfile();
        var width = dc.getWidth();
        var height = dc.getHeight();
        if (height > width * 1.1) {
            profile.shape = RosaryConstants.SHAPE_RECTANGLE;
        }
        if (width <= 176 && height <= 176) {
            profile.isInstinct = true;
            profile.isMonochrome = true;
        } else if (dc has :getColorDepth) {
            profile.isMonochrome = (dc.getColorDepth() <= 2);
        }
        return profile;
    }
}

class Palette {
    static const COLOR_WHITE = 0xFFFFFF;

    private var _monochrome as Boolean;

    function initialize(monochrome as Boolean) {
        _monochrome = monochrome;
    }

    static function forProfile(profile as DeviceProfile) as Palette {
        return new Palette(profile.isMonochrome);
    }

    function background() as Number {
        return 0x000000;
    }

    function accentForMystery(mysteryType as Number) as Number {
        return _monochrome ? COLOR_WHITE : 0xFFD700;
    }

    function textPrimary() as Number {
        return COLOR_WHITE;
    }

    function isMonochrome() as Boolean {
        return _monochrome;
    }
}
