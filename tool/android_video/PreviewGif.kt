package com.example.b_music02

import android.graphics.Bitmap
import java.io.OutputStream
import java.io.ByteArrayOutputStream

/** Bounded 256-color GIF preview writer. Resets the LZW dictionary before code growth. */
class PreviewGif(private val out:OutputStream,private val width:Int,private val height:Int) {
    private fun word(v:Int) { out.write(v and 255); out.write((v ushr 8) and 255) }
    init {
        out.write("GIF89a".toByteArray(Charsets.US_ASCII)); word(width); word(height)
        out.write(byteArrayOf(0xF7.toByte(),0,0))
        for(i in 0..255) { out.write(((i ushr 5) and 7)*255/7); out.write(((i ushr 2) and 7)*255/7); out.write((i and 3)*255/3) }
        out.write(byteArrayOf(0x21,0xFF.toByte(),11)); out.write("NETSCAPE2.0".toByteArray(Charsets.US_ASCII)); out.write(byteArrayOf(3,1,0,0,0))
    }
    fun frame(bitmap:Bitmap) {
        out.write(byteArrayOf(0x21,0xF9.toByte(),4,4,17,0,0,0))
        out.write(0x2C); word(0); word(0); word(width); word(height); out.write(0); out.write(8)
        val bytes=ByteArrayOutputStream(); var accumulator=0; var bits=0
        fun code(value:Int) { accumulator=accumulator or (value shl bits); bits+=9; while(bits>=8) { bytes.write(accumulator and 255); accumulator=accumulator ushr 8; bits-=8 } }
        val pixels=IntArray(width*height); bitmap.getPixels(pixels,0,width,0,0,width,height)
        var count=0; code(256)
        for(pixel in pixels) { if(count==200) { code(256); count=0 }; code(((pixel ushr 16 and 255) ushr 5 shl 5) or ((pixel ushr 8 and 255) ushr 5 shl 2) or ((pixel and 255) ushr 6)); count++ }
        code(257); if(bits>0) bytes.write(accumulator and 255)
        val data=bytes.toByteArray(); var at=0
        while(at<data.size) { val n=minOf(255,data.size-at); out.write(n); out.write(data,at,n); at+=n }; out.write(0)
    }
    fun finish() { out.write(0x3B); out.flush() }
}
