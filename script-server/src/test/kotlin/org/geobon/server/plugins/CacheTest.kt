package org.geobon.server.plugins

import org.geobon.pipeline.outputRoot
import java.io.File
import kotlin.test.assertTrue
import kotlin.test.*

private const val DUMMY_TEXT = "Some content"

class CacheTest {
    private var someDir = File(outputRoot, "someDir")
    private var someFile = File(someDir, "someFile")

    @BeforeTest
    fun setupOutputFolder() {
        with(outputRoot) {
            assertTrue(!exists())
            mkdirs()
            assertTrue(exists())
        }

        someDir.mkdir()
        someFile.writeText(DUMMY_TEXT)
    }

    @AfterTest
    fun removeOutputFolder() {
        assertTrue(outputRoot.deleteRecursively())
    }

    @Test
    fun givenCacheVersionSame_whenCheckCache_thenNothingDone() {
        CACHE_VERSION_FILE.writeText(CACHE_VERSION)
        assertEquals(2, outputRoot.listFiles()?.size)

        checkCacheVersion()

        assertEquals(CACHE_VERSION, CACHE_VERSION_FILE.readText())

        assertEquals(2, outputRoot.listFiles()?.size)
        assertTrue(someDir.isDirectory)
        assertTrue(someFile.exists())
        assertEquals(DUMMY_TEXT, someFile.readText())
    }

    @Test
    fun givenCacheVersionNotSet_whenCheckCache_thenMovedToCacheVersion0() {
        assertEquals(1, outputRoot.listFiles()?.size)

        checkCacheVersion()

        assertEquals(CACHE_VERSION, CACHE_VERSION_FILE.readText())

        assertEquals(2, outputRoot.listFiles()?.size)
        assertFalse(someDir.exists())
        assertFalse(someFile.exists())

        val archive = File(outputRoot, "OLD_v0")
        assertTrue(archive.isDirectory)
        val someDirArchive = File(archive, "someDir")
        assertTrue(someDirArchive.isDirectory)
        val someFileArchive = File(someDirArchive, "someFile")
        assertTrue(someFileArchive.exists())
        assertEquals(DUMMY_TEXT, someFileArchive.readText())
    }

    @Test
    fun givenCacheVersionDifferent_whenCheckCache_thenMovedToCacheVersion0() {
        CACHE_VERSION_FILE.writeText("1.0")
        assertEquals(2, outputRoot.listFiles()?.size)

        checkCacheVersion()

        assertEquals(CACHE_VERSION, CACHE_VERSION_FILE.readText())

        assertEquals(2, outputRoot.listFiles()?.size)
        assertFalse(someDir.exists())
        assertFalse(someFile.exists())

        val archive = File(outputRoot, "OLD_v1.0")
        assertTrue(archive.isDirectory)
        val someDirArchive = File(archive, "someDir")
        assertTrue(someDirArchive.isDirectory)
        val someFileArchive = File(someDirArchive, "someFile")
        assertTrue(someFileArchive.exists())
        assertEquals(DUMMY_TEXT, someFileArchive.readText())
    }

    @Test
    fun givenGitignoreFile_whenCacheMoved_thenStaysThere() {
        CACHE_VERSION_FILE.writeText("1.0")
        val gitignore = File(outputRoot, ".gitignore")
        gitignore.createNewFile()

        checkCacheVersion()

        assertTrue(gitignore.exists())
    }
}