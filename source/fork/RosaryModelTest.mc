import Toybox.Lang;
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
