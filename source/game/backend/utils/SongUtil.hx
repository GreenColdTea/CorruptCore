package game.backend.utils;

class SongUtil
{
    private static final _invalidCharsRegex = ~/[~&\\;:<>#]/g;
    private static final _hideCharsRegex = ~/[.,'"%?!]/g;

    inline static public function formatToSongPath(path:String):String 
    {
        final dashedPath = _invalidCharsRegex.replace(path.replace(' ', '-'), "-");
        return _hideCharsRegex.replace(dashedPath, "").toLowerCase();
    }
}