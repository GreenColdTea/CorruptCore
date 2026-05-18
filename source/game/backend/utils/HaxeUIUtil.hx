package game.backend.utils;

import flixel.FlxG;
import haxe.ui.core.Component;
import haxe.ui.containers.dialogs.Dialogs;
import haxe.ui.containers.dialogs.Dialog.DialogButton;
import haxe.ui.containers.dialogs.MessageBox.MessageBoxType;
import haxe.ui.notifications.NotificationManager;
import haxe.ui.notifications.NotificationType;

final class HaxeUIUtil
{
    public static var isCursorOverUI(get, never):Bool;
    private static function get_isCursorOverUI():Bool
    {
        return haxe.ui.core.Screen.instance?.hasSolidComponentUnderPoint(FlxG.mouse.gameX, FlxG.mouse.gameY) ?? false;
    }
    
    public static function showNotification(title:String, body:String, ?type:NotificationType = Info, ?icon:String = null):Void
    {
        NotificationManager.instance.addNotification({
            title: title,
            body: body,
            type: type,
            icon: icon
        });
    }

    public static function showAlert(message:String, ?title:String = "Warning", ?onComplete:(btn:DialogButton)->Void):Void
    {
        Dialogs.messageBox(message, title, MessageBoxType.TYPE_WARNING, true, onComplete);
    }

    public static function showConfirm(message:String, ?title:String = "Confirmation", ?onComplete:(btn:DialogButton)->Void):Void
    {
        Dialogs.messageBox(message, title, MessageBoxType.TYPE_YESNO, true, onComplete);
    }

    public static function showDialog(message:String, title:String, buttons:DialogButton, ?onComplete:(btn:DialogButton)->Void):Void
    {
        final dialog = Dialogs.messageBox(message, title, MessageBoxType.TYPE_INFO, true, onComplete);
        dialog.buttons = buttons;
        dialog.show();
    }

    public static function showCustomDialog(title:String, content:Component, ?buttons:DialogButton = DialogButton.OK, ?onComplete:(btn:DialogButton)->Void):Dynamic
    {
        return Dialogs.dialog(content, title, buttons, true, onComplete);
    }
}