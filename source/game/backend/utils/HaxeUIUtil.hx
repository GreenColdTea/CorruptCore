package game.backend.utils;

import haxe.ui.*;
import haxe.ui.notifications.NotificationManager;
import haxe.ui.notifications.NotificationType;

final class HaxeUIUtil
{
    public static function showNotification(title:String, body:String, ?type:NotificationType = Info, ?icon:String = null)
    {
        NotificationManager.instance.addNotification({
            title: title,
            body: body,
            type: type,
            icon: icon
        });
    }
}