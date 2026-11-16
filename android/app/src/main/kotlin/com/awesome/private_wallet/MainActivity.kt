package com.awesome.private_wallet

import android.Manifest
import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.ConnectivityManager
import android.net.NetworkCapabilities
import android.net.Uri
import android.os.Build
import android.os.PowerManager
import android.provider.Settings
import androidx.biometric.BiometricManager
import androidx.biometric.BiometricPrompt
import androidx.core.app.ActivityCompat
import androidx.core.app.NotificationCompat
import androidx.core.content.ContextCompat
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterFragmentActivity() {
    private val channelPermissions = "com.awesome/permissions"
    private val channelNotifications = "com.awesome/notifications"
    private val channelAuth = "com.awesome/auth"
    private val notificationChannelId = "private_wallet_transactions"
    private val allowedAuthenticators = BiometricManager.Authenticators.BIOMETRIC_STRONG or
            BiometricManager.Authenticators.BIOMETRIC_WEAK or
            BiometricManager.Authenticators.DEVICE_CREDENTIAL

    override fun onCreate(savedInstanceState: android.os.Bundle?) {
        super.onCreate(savedInstanceState)
        androidx.core.view.WindowCompat.setDecorFitsSystemWindows(window, false)
    }

    /** Registra os canais Flutter para permissões, notificações e autenticação. */
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        createNotificationChannel()

        // Canal de Permissões
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelPermissions).setMethodCallHandler { call, result ->
            when (call.method) {
                "checkPermission" -> {
                    val permission = call.argument<String>("permission") ?: ""
                    result.success(isPermissionGranted(permission))
                }
                "requestPermission" -> {
                    val permission = call.argument<String>("permission") ?: ""
                    requestSinglePermission(permission)
                    result.success(true)
                }
                "openAppSettings" -> {
                    openSettings()
                    result.success(true)
                }
                "requestBatteryOptimization" -> {
                    requestIgnoreBatteryOptimization()
                    result.success(true)
                }
                "getNetworkType" -> {
                    result.success(getNetworkType())
                }
                else -> result.notImplemented()
            }
        }

        // Canal de Notificações
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelNotifications).setMethodCallHandler { call, result ->
            when (call.method) {
                "showNotification" -> {
                    val title = call.argument<String>("title") ?: "Private Wallet"
                    val body = call.argument<String>("body") ?: ""
                    val id = call.argument<Int>("id") ?: 1001
                    showNativeNotification(id, title, body)
                    result.success(true)
                }
                else -> result.notImplemented()
            }
        }

        // Canal de Autenticação Biométrica e Facial
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelAuth).setMethodCallHandler { call, result ->
            when (call.method) {
                "canAuthenticateBiometrics" -> {
                    val biometricManager = BiometricManager.from(this)
                    val canAuth = biometricManager.canAuthenticate(allowedAuthenticators) == BiometricManager.BIOMETRIC_SUCCESS
                    result.success(canAuth)
                }
                "authenticateBiometrics" -> {
                    val title = call.argument<String>("title") ?: "Autenticação Private Wallet"
                    val subtitle = call.argument<String>("subtitle") ?: "Confirme sua identidade biométrica ou facial"

                    val executor = ContextCompat.getMainExecutor(this)
                    val promptInfo = BiometricPrompt.PromptInfo.Builder()
                        .setTitle(title)
                        .setSubtitle(subtitle)
                        .setAllowedAuthenticators(allowedAuthenticators)
                        .build()

                    var hasResponded = false
                    val biometricPrompt = BiometricPrompt(this, executor, object : BiometricPrompt.AuthenticationCallback() {
                        /** Conclui a chamada Flutter com sucesso uma única vez. */
                        override fun onAuthenticationSucceeded(authResult: BiometricPrompt.AuthenticationResult) {
                            super.onAuthenticationSucceeded(authResult)
                            if (!hasResponded) {
                                hasResponded = true
                                result.success(true)
                            }
                        }

                        /** Conclui a chamada Flutter após cancelamento ou erro terminal. */
                        override fun onAuthenticationError(errorCode: Int, errString: CharSequence) {
                            super.onAuthenticationError(errorCode, errString)
                            if (!hasResponded) {
                                hasResponded = true
                                result.success(false)
                            }
                        }

                    })

                    biometricPrompt.authenticate(promptInfo)
                }
                else -> result.notImplemented()
            }
        }
    }

    /** Consulta a permissão correspondente à versão do Android. */
    private fun isPermissionGranted(permission: String): Boolean {
        return when (permission) {
            "notification" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    ContextCompat.checkSelfPermission(this, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
                } else {
                    true
                }
            }
            "storage" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    true
                } else {
                    ContextCompat.checkSelfPermission(this, Manifest.permission.WRITE_EXTERNAL_STORAGE) == PackageManager.PERMISSION_GRANTED
                }
            }
            "background" -> {
                val powerManager = getSystemService(Context.POWER_SERVICE) as PowerManager
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    powerManager.isIgnoringBatteryOptimizations(packageName)
                } else {
                    true
                }
            }
            "network" -> {
                ContextCompat.checkSelfPermission(this, Manifest.permission.ACCESS_NETWORK_STATE) == PackageManager.PERMISSION_GRANTED
            }
            else -> false
        }
    }

    /** Abre o pedido de permissão aplicável para o recurso informado. */
    private fun requestSinglePermission(permission: String) {
        when (permission) {
            "notification" -> {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
                    ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.POST_NOTIFICATIONS), 101)
                }
            }
            "storage" -> {
                if (Build.VERSION.SDK_INT < Build.VERSION_CODES.Q) {
                    ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.WRITE_EXTERNAL_STORAGE), 102)
                }
            }
            "background" -> {
                requestIgnoreBatteryOptimization()
            }
            "network" -> {
                ActivityCompat.requestPermissions(this, arrayOf(Manifest.permission.ACCESS_NETWORK_STATE), 104)
            }
        }
    }

    /** Solicita uma exceção de bateria ou abre as configurações do aplicativo. */
    private fun requestIgnoreBatteryOptimization() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            try {
                val intent = Intent(Settings.ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS).apply {
                    data = Uri.parse("package:$packageName")
                }
                startActivity(intent)
            } catch (e: Exception) {
                openSettings()
            }
        }
    }

    /** Abre a tela de configurações do Android para este pacote. */
    private fun openSettings() {
        val intent = Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS).apply {
            data = Uri.parse("package:$packageName")
        }
        startActivity(intent)
    }

    /** Classifica o transporte da conexão ativa ou informa ausência de conexão. */
    private fun getNetworkType(): String {
        val cm = getSystemService(Context.CONNECTIVITY_SERVICE) as ConnectivityManager
        val network = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            cm.activeNetwork ?: return "offline"
        } else {
            return "cellular"
        }
        val capabilities = cm.getNetworkCapabilities(network) ?: return "offline"
        return when {
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_WIFI) -> "wifi"
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_CELLULAR) -> "cellular"
            capabilities.hasTransport(NetworkCapabilities.TRANSPORT_ETHERNET) -> "ethernet"
            else -> "other"
        }
    }

    /** Registra o canal de transações em versões que exigem um canal. */
    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "Notificações de Transações"
            val descriptionText = "Notificações de transações, confirmações e segurança da carteira"
            val importance = NotificationManager.IMPORTANCE_DEFAULT
            val channel = NotificationChannel(notificationChannelId, name, importance).apply {
                description = descriptionText
            }
            val notificationManager: NotificationManager =
                getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    /** Publica uma notificação nativa com o conteúdo recebido do Flutter. */
    private fun showNativeNotification(id: Int, title: String, message: String) {
        val builder = NotificationCompat.Builder(this, notificationChannelId)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(message)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)

        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        notificationManager.notify(id, builder.build())
    }
}
