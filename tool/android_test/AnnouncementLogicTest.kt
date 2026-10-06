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

    @Test fun pushDataBecomesAnnouncementWithSameRules() {
        val item = AnnouncementLogic.fromPush(mapOf("id" to " p1 ", "title" to "Anlık", "body" to "Metin",
            "url" to "https://example.com/x", "createdAt" to "2026-10-07T10:00:00+03:00"), 5L, "0:1")!!
        assertEquals("p1", item.id)
        assertEquals("Anlık", item.title)
        assertEquals("https://example.com/x", item.url)
        assertEquals(AnnouncementLogic.time("2026-10-07T07:00:00Z"), item.createdAt)
        val fallback = AnnouncementLogic.fromPush(mapOf("title" to "Konsol", "url" to "http://insecure"), 1791296100000L, "0:9")!!
        assertEquals("fcm-0:9", fallback.id)
        assertNull(fallback.url)
        assertEquals(1791296100000L, fallback.createdAt)
        assertNull(AnnouncementLogic.fromPush(mapOf("id" to "x"), 0L, null))
        assertNull(AnnouncementLogic.fromPush(mapOf("title" to "Kimliksiz"), 0L, null))
        assertEquals(1000, AnnouncementLogic.fromPush(mapOf("id" to "b", "title" to "t", "body" to "x".repeat(5000)), 0L, null)!!.body.length)
    }

    @Test fun pushedListIsAnnouncementsJsonDedupedAndBounded() {
        var json: String? = null
        for (i in 1..55) json = AnnouncementLogic.addPushed(json, Announcement("p$i", "T$i", "", null, 1791296100000L + i * 1000))
        json = AnnouncementLogic.addPushed(json, Announcement("p55", "Yeniden", "", "https://e.com", null))
        val items = AnnouncementLogic.parse(json!!)
        assertEquals(50, items.size)
        assertEquals(1, items.count { it.id == "p55" })
        assertEquals("Yeniden", items.first { it.id == "p55" }.title)
        assertTrue(items.none { it.id == "p1" })
        assertEquals(1791296101000L + 9000, items.first { it.id == "p10" }.createdAt)
        // A pushed id is a seen id: the announcements.json copy is not notified again.
        val (notify, _) = AnnouncementLogic.select(AnnouncementLogic.parse("""{"announcements":[{"id":"p55","title":"Aynı","createdAt":"2030-01-01T00:00:00Z"}]}"""),
            items.map { it.id }.toSet(), since, false)
        assertTrue(notify.isEmpty())
        assertEquals(1, AnnouncementLogic.parse(AnnouncementLogic.addPushed("bozuk", Announcement("a", "b", "", null, null))).size)
    }
}
