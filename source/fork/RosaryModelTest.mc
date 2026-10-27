import Toybox.Graphics;
import Toybox.Lang;
import Toybox.System;
import Toybox.Test;

//! FORK: prayer sequence checks. Build with -t and run with `monkeydo <prg> <device> /t` (Windows; -t elsewhere).

(:test)
function rosarySequenceEndsWithSalveAndOratio(logger as Logger) as Boolean {
    var model = new RosaryModel();
    model.setAutoMystery();

    var expected = [
        RosaryModel.STATE_CROSS,
        RosaryModel.STATE_CREED,
        RosaryModel.STATE_INTRO_OUR_FATHER,
        RosaryModel.STATE_INTRO_HAIL_MARY,
        RosaryModel.STATE_INTRO_HAIL_MARY,
        RosaryModel.STATE_INTRO_HAIL_MARY,
        RosaryModel.STATE_INTRO_GLORY
    ] as Array<Number>;
    for (var decade = 0; decade < 5; decade++) {
        expected.add(RosaryModel.STATE_OUR_FATHER);
        for (var i = 0; i < 10; i++) {
            expected.add(RosaryModel.STATE_HAIL_MARY);
        }
        expected.add(RosaryModel.STATE_GLORY);
    }
    expected.add(RosaryModel.STATE_SALVE);
    expected.add(RosaryModel.STATE_ORATIO);
    expected.add(RosaryModel.STATE_COMPLETE);

    for (var i = 0; i < expected.size(); i++) {
        var state = model.next();
        if (state != expected[i]) {
            logger.error("step " + (i + 1) + ": expected " + expected[i] + ", got " + state);
            return false;
        }
        if (!model.isComplete && model.getCurrentState() != state) {
            logger.error("step " + (i + 1) + ": getCurrentState() " + model.getCurrentState() + " != " + state);
            return false;
        }
    }

    Test.assertEqualMessage(model.getProgress(), 1.0f, "progress at the end");
    return true;
}

(:test)
function previousStepsBackThroughClosingPrayers(logger as Logger) as Boolean {
    var model = new RosaryModel();
    model.setAutoMystery();
    while (!model.isComplete) {
        model.next();
    }

    model.previous();
    Test.assertEqualMessage(model.getCurrentState(), RosaryModel.STATE_ORATIO, "back from the end");
    model.previous();
    Test.assertEqualMessage(model.getCurrentState(), RosaryModel.STATE_SALVE, "back from Modleme se");
    model.previous();
    Test.assertEqualMessage(model.getCurrentState(), RosaryModel.STATE_GLORY, "back from Zdrávas Královno");
    Test.assertEqualMessage(model.getCurrentDecade(), 5, "back in the 5th decade");
    return true;
}

(:test)
function fullRosaryEndsWithSalveAndOratio(logger as Logger) as Boolean {
    var model = new RosaryModel();
    model.startFullRosary();

    var states = [] as Array<Number>;
    var guard = 0;
    while (!model.isComplete && guard < 400) {
        states.add(model.next());
        guard++;
    }
    var n = states.size();
    Test.assertMessage(n >= 3, "rosary completes");
    Test.assertEqualMessage(states[n - 3], RosaryModel.STATE_SALVE, "Salve after last decade");
    Test.assertEqualMessage(states[n - 2], RosaryModel.STATE_ORATIO, "then Modleme se");
    Test.assertEqualMessage(states[n - 1], RosaryModel.STATE_COMPLETE, "then complete");
    Test.assertEqualMessage(model.mysteryType, RosaryModel.MYSTERY_LUMINOUS, "ends with luminous");
    return true;
}

(:test)
function skipJumpsToTheNextOurFather(logger as Logger) as Boolean {
    var model = new RosaryModel();
    model.setAutoMystery();

    // from the start screen: Sign of the Cross and the Creed are skipped, stops at the first Our Father
    Test.assertEqualMessage(model.skipToNextOurFather(), RosaryModel.STATE_INTRO_OUR_FATHER, "skip from the start");
    // the introductory Hail Marys and Glory are skipped, stops at the Our Father of the first decade
    Test.assertEqualMessage(model.skipToNextOurFather(), RosaryModel.STATE_OUR_FATHER, "skip from the intro");
    Test.assertEqualMessage(model.getCurrentDecade(), 1, "first decade");
    Test.assertEqualMessage(model.totalBeads, 8, "beads counted through the skipped ones");

    // in the middle of a decade
    for (var i = 0; i < 4; i++) {
        model.next();
    }
    Test.assertEqualMessage(model.getCurrentState(), RosaryModel.STATE_HAIL_MARY, "inside the decade");
    Test.assertEqualMessage(model.skipToNextOurFather(), RosaryModel.STATE_OUR_FATHER, "skip inside a decade");
    Test.assertEqualMessage(model.getCurrentDecade(), 2, "second decade");
    Test.assertEqualMessage(model.beadInPhase, 1, "on the Our Father bead");
    Test.assertEqualMessage(model.totalBeads, 20, "progress follows the skipped beads");

    // from an Our Father itself the next one is in the following decade
    Test.assertEqualMessage(model.skipToNextOurFather(), RosaryModel.STATE_OUR_FATHER, "skip from an Our Father");
    Test.assertEqualMessage(model.getCurrentDecade(), 3, "third decade");

    // last decade: on to the Salve Regina, then the closing prayer, then the end
    model.skipToNextOurFather();
    model.skipToNextOurFather();
    Test.assertEqualMessage(model.getCurrentDecade(), 5, "fifth decade");
    Test.assertEqualMessage(model.skipToNextOurFather(), RosaryModel.STATE_SALVE, "skip from the last decade");
    Test.assertEqualMessage(model.skipToNextOurFather(), RosaryModel.STATE_ORATIO, "skip from the Salve");
    Test.assertEqualMessage(model.skipToNextOurFather(), RosaryModel.STATE_COMPLETE, "skip from the closing prayer");
    Test.assertMessage(model.isComplete, "rosary complete");
    Test.assertEqualMessage(model.getProgress(), 1.0f, "progress at the end");

    // a skip on the finished screen only restarts, like a normal step
    Test.assertEqualMessage(model.skipToNextOurFather(), RosaryModel.STATE_CROSS, "skip after the end restarts");
    Test.assertEqualMessage(model.totalBeads, 0, "restarted");
    return true;
}

(:test)
function skipStopsAtMysteryTransitionInFullRosary(logger as Logger) as Boolean {
    var model = new RosaryModel();
    model.startFullRosary();

    model.skipToNextOurFather(); // introductory Our Father
    for (var decade = 1; decade <= 5; decade++) {
        Test.assertEqualMessage(model.skipToNextOurFather(), RosaryModel.STATE_OUR_FATHER, "decade " + decade);
    }
    Test.assertEqualMessage(model.getCurrentDecade(), 5, "fifth decade of the joyful mysteries");
    Test.assertEqualMessage(model.skipToNextOurFather(), RosaryModel.STATE_MYSTERY_TRANSITION, "transition screen");
    Test.assertEqualMessage(model.skipToNextOurFather(), RosaryModel.STATE_OUR_FATHER, "first decade of the next mysteries");
    Test.assertEqualMessage(model.mysteryType, RosaryModel.MYSTERY_SORROWFUL, "sorrowful follow joyful");
    Test.assertEqualMessage(model.getCurrentDecade(), 1, "back to the first decade");
    return true;
}

(:test)
function prayerTextsDoNotEndWithAStubPage(logger as Logger) as Boolean {
    var settings = System.getDeviceSettings();
    var options = {:width => settings.screenWidth, :height => settings.screenHeight};
    var bitmap = null;
    if (Graphics has :createBufferedBitmap) {
        bitmap = Graphics.createBufferedBitmap(options).get();
    } else {
        bitmap = new Graphics.BufferedBitmap(options); // older devices
    }
    var dc = (bitmap as Graphics.BufferedBitmap).getDc();

    var ok = true;
    var states = [RosaryModel.STATE_CREED, RosaryModel.STATE_SALVE, RosaryModel.STATE_ORATIO] as Array<Number>;
    for (var i = 0; i < states.size(); i++) {
        var view = new PrayerTextView(states[i]);
        view.onLayout(dc);
        var sizes = view.getPageSizes();
        logger.debug("state " + states[i] + " on " + settings.screenWidth + "x" + settings.screenHeight + ": lines per page " + sizes);
        // the fenix 7X (280x280) must not end on a one- or two-line page
        if (settings.screenWidth == 280 && settings.screenHeight == 280 && sizes.size() > 1 && sizes[sizes.size() - 1] <= 2) {
            logger.error("stub last page for state " + states[i]);
            ok = false;
        }
    }
    return ok;
}
