package com.bmusic.app

import java.util.Calendar
import java.util.TimeZone
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class AlarmLogicTest {
    private val zone = TimeZone.getTimeZone("Europe/Istanbul")

    /** 2026-10-07 is a Wednesday (ISO day 3). */
    private fun at(day: Int, hour: Int, minute: Int, month: Int = Calendar.OCTOBER, year: Int = 2026): Long =
        Calendar.getInstance(zone).apply { clear(); set(year, month, day, hour, minute, 0) }.timeInMillis

    @Test fun oneShotLaterToday() {
        assertEquals(at(7, 9, 0), AlarmLogic.nextTrigger(at(7, 8, 30), 9, 0, emptySet(), zone))
    }

    @Test fun oneShotAlreadyPassedRingsTomorrow() {
        assertEquals(at(8, 7, 0), AlarmLogic.nextTrigger(at(7, 8, 30), 7, 0, emptySet(), zone))
        // Same minute as now: never fires immediately, waits one day.
        assertEquals(at(8, 8, 30), AlarmLogic.nextTrigger(at(7, 8, 30), 8, 30, emptySet(), zone))
    }

    @Test fun repeatingPicksNextSelectedDay() {
        // Wednesday 08:30, alarm on Mon(1) and Fri(5) at 07:00 -> Friday 9 Oct.
        assertEquals(at(9, 7, 0), AlarmLogic.nextTrigger(at(7, 8, 30), 7, 0, setOf(1, 5), zone))
        // Only Wednesday, already passed -> next Wednesday.
        assertEquals(at(14, 7, 0), AlarmLogic.nextTrigger(at(7, 8, 30), 7, 0, setOf(3), zone))
        // Sunday is ISO 7.
        assertEquals(at(11, 10, 0), AlarmLogic.nextTrigger(at(7, 8, 30), 10, 0, setOf(7), zone))
    }

    @Test fun crossesMonthAndYear() {
        assertEquals(at(1, 6, 0, Calendar.JANUARY, 2027), AlarmLogic.nextTrigger(at(31, 23, 0, Calendar.DECEMBER), 6, 0, emptySet(), zone))
    }

    @Test fun isoDays() {
        assertEquals(1, AlarmLogic.isoDay(Calendar.MONDAY))
        assertEquals(7, AlarmLogic.isoDay(Calendar.SUNDAY))
        assertEquals(6, AlarmLogic.isoDay(Calendar.SATURDAY))
    }

    @Test fun parsesStoredAlarmsAndSkipsBrokenOnes() {
        val alarms = AlarmSpec.parseAll("""[{"id":3,"hour":6,"minute":45,"days":[1,2,3],"enabled":true,"songPath":"/sdcard/Music/a.mp3","songTitle":"A"},"x"]""")
        assertEquals(1, alarms.size)
        assertEquals(setOf(1, 2, 3), alarms[0].days)
        assertTrue(alarms[0].enabled)
        assertEquals(emptyList<AlarmSpec>(), AlarmSpec.parseAll("not json"))
    }
}
