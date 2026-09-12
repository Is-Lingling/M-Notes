package com.markdownnotes.app

import android.annotation.SuppressLint
import android.net.Uri
import android.os.Bundle
import android.webkit.JavascriptInterface
import android.webkit.WebChromeClient
import android.webkit.WebView
import android.webkit.WebViewClient
import androidx.activity.result.contract.ActivityResultContracts
import androidx.appcompat.app.AppCompatActivity
import java.io.BufferedReader
import java.io.InputStreamReader

class MainActivity : AppCompatActivity() {

    private lateinit var webView: WebView
    private var currentFileUri: Uri? = null
    private var currentContent: String = "# Welcome to M Notes on Android\n\n- [x] True WYSIWYG Editing\n- [x] KaTeX & Mermaid\n"

    private val openDocumentLauncher = registerForActivityResult(
        ActivityResultContracts.OpenDocument()
    ) { uri: Uri? ->
        uri?.let { openFileFromUri(it) }
    }

    private val createDocumentLauncher = registerForActivityResult(
        ActivityResultContracts.CreateDocument("text/markdown")
    ) { uri: Uri? ->
        uri?.let { saveFileToUri(it) }
    }

    @SuppressLint("SetJavaScriptEnabled")
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        webView = WebView(this).apply {
            settings.javaScriptEnabled = true
            settings.domStorageEnabled = true
            settings.allowFileAccess = true
            settings.allowContentAccess = true

            webChromeClient = WebChromeClient()
            webViewClient = object : WebViewClient() {
                override fun onPageFinished(view: WebView?, url: String?) {
                    super.onPageFinished(view, url)
                    view?.evaluateJavaScript("window.editor?.setContent(${escapeJs(currentContent)})", null)
                }
            }

            addJavascriptInterface(AndroidBridge(), "AndroidBridge")
        }

        setContentView(webView)

        // Load editor
        webView.loadUrl("file:///android_asset/editor/editor.html")

        // Handle file open from intent
        intent?.data?.let { openFileFromUri(it) }
    }

    private fun openFileFromUri(uri: Uri) {
        try {
            contentResolver.openInputStream(uri)?.use { inputStream ->
                val reader = BufferedReader(InputStreamReader(inputStream))
                val content = reader.readText()
                currentFileUri = uri
                currentContent = content
                webView.evaluateJavaScript("window.editor?.setContent(${escapeJs(content)})", null)
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }
    }

    private fun saveFileToUri(uri: Uri) {
        webView.evaluateJavaScript("window.editor?.getContent()") { value ->
            val unquoted = value?.removeSurrounding("\"")?.replace("\\n", "\n") ?: currentContent
            try {
                contentResolver.openOutputStream(uri)?.use { outputStream ->
                    outputStream.write(unquoted.toByteArray())
                }
                currentFileUri = uri
            } catch (e: Exception) {
                e.printStackTrace()
            }
        }
    }

    private fun escapeJs(str: String): String {
        return "\"" + str.replace("\\", "\\\\")
            .replace("\"", "\\\"")
            .replace("\n", "\\n")
            .replace("\r", "") + "\""
    }

    inner class AndroidBridge {
        @JavascriptInterface
        fun requestOpenFile() {
            openDocumentLauncher.launch(arrayOf("text/markdown", "text/plain", "*/*"))
        }

        @JavascriptInterface
        fun requestSaveFile() {
            if (currentFileUri != null) {
                saveFileToUri(currentFileUri!!)
            } else {
                createDocumentLauncher.launch("Untitled.md")
            }
        }
    }
}
