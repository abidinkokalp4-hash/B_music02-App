package com.example.b_music02

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class AnnouncementLogicTest {
    private val json = """{"announcements":[
        {"id":"old","title":"Eski","body":"b","createdAt":"2026-01-01T10:00:00+03:00"},
        {"id":"new","title":"Yeni","body":"b","url":"https://example.com","createdAt":"2026-10-07T10:00:00Z"},
        {"id":"undated","title":"Tarihsiz","body":"b"},
        {"id":"new","title":"Kopya","body":"b"},
        {"id":"","title":"Kimliksiz"},
        {"id":"bad-url","title":"Link","url":"http://insecure.example","createdAt":"2026-10-08"},
        "not an object"
    ]}"""
    private val since = AnnouncementLogic.time("2026-10-06T20:00:00Z")!!

    @Test fun parsesValidEntriesNewestFirst() {
        val items = AnnouncementLogic.parse(json)
        assertEquals(listOf("bad-url", "new", "old", "undated"), items.map { it.id })
        assertEquals("https://example.com", items.first { it.id == "new" }.url)
        assertNull(items.first { it.id == "bad-url" }.url)
        assertTrue(AnnouncementLogic.parse("not json").isEmpty())
        assertTrue(AnnouncementLogic.parse("""{"announcements":[]}""").isEmpty())
    }

    @Test fun firstCheckOnlyNotifiesAnnouncementsNewerThanInstall() {
        val items = AnnouncementLogic.parse(json)
        val (notify, seen) = AnnouncementLogic.select(items, emptySet(), since, firstCheck = true)
        assertEquals(listOf("new", "bad-url"), notify.map { it.id })
        assertEquals(setOf("old", "new", "undated", "bad-url"), seen)
    }

    @Test fun seenIdsAreNeverNotifiedAgainAndUndatedOnesNotifyLater() {
        val items = AnnouncementLogic.parse(json)
        val (again, _) = AnnouncementLogic.select(items, setOf("old", "new", "undated", "bad-url"), since, firstCheck = false)
        assertTrue(again.isEmpty())
        val (later, _) = AnnouncementLogic.select(items, setOf("old", "new", "bad-url"), since, firstCheck = false)
        assertEquals(listOf("undated"), later.map { it.id })
    }

    @Test fun parsesIsoTimesWithOffsets() {
        assertEquals(AnnouncementLogic.time("2026-10-06T17:00:00Z"), AnnouncementLogic.time("2026-10-06T20:00:00+03:00"))
        assertEquals(AnnouncementLogic.time("2026-10-06T00:00:00Z"), AnnouncementLogic.time("2026-10-06"))
        assertEquals(1791296100000L, AnnouncementLogic.time("2026-10-06T14:15:00.500Z"))
        assertNull(AnnouncementLogic.time("2026-13-40"))
        assertNull(AnnouncementLogic.time("dün"))
    }

    @Test fun atMostThreePerCheck() {
        val many = (1..6).joinToString(",") { """{"id":"a$it","title":"T$it","createdAt":"2026-10-1${it}T00:00:00Z"}""" }
        val (notify, seen) = AnnouncementLogic.select(AnnouncementLogic.parse("""{"announcements":[$many]}"""), emptySet(), since, false)
        assertEquals(listOf("a4", "a5", "a6"), notify.map { it.id })
        assertEquals(6, seen.size)
    }
}
