/**
 * Copyright (c) 2018 Level Up Labs, LLC
 * 
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 * 
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 * 
 */

package polymod.backends;

import polymod.Polymod;
import polymod.util.Util;
import polymod.Polymod.FrameworkParams;
import polymod.backends.PolymodAssetLibrary;
import polymod.backends.PolymodAssets.PolymodAssetType;
#if unifill
import unifill.Unifill;
#end
#if (lime && !nme)
import lime.app.Future;
import lime.utils.Assets;
import lime.net.HTTPRequest;
import lime.graphics.Image;
import lime.text.Font;
import lime.utils.Bytes;
#if (lime >= "4.0.0")
import lime.utils.AssetLibrary;
import lime.media.AudioBuffer;
import lime.utils.AssetType;
#else
import lime.Assets.AssetType;
import lime.Assets.AssetLibrary;
import lime.audio.AudioBuffer;
#end
#end
using StringTools;

#if (!lime || nme)
class LimeBackend extends StubBackend
{
	public function new()
	{
		super();
		Polymod.error(FAILED_CREATE_BACKEND, "LimeBackend requires the lime library, did you forget to install it?");
	}
}
#else
#if !nme
class LimeBackend implements IBackend
{
	// STATIC:
	private static var defaultAssetLibraries:Map<String, AssetLibrary>;

	/**
	 * Find all the registered access libraries and store keyed references to them
	 */
	private static function getDefaultAssetLibraries()
	{
		if (defaultAssetLibraries == null)
		{
			defaultAssetLibraries = new Map<String, AssetLibrary>();

			// I don't like having to do this but there's no other way, hope the internals don't change!
			var libraries = @:privateAccess lime.utils.Assets.libraries;

			// Find every asset library and make a copy of it
			for (key in libraries.keys())
			{
				defaultAssetLibraries.set(key, lime.utils.Assets.getLibrary(key));
			}
		}
		return defaultAssetLibraries;
	}

	/**
	 * Re-register all the asset libraries recorded by `getDefaultAssetLibraries()`
	 */
	private static function restoreDefaultAssetLibraries()
	{
		if (defaultAssetLibraries != null)
		{
			for (key in defaultAssetLibraries.keys())
			{
				Assets.registerLibrary(key, defaultAssetLibraries.get(key));
			}
		}
	}

	// Instance:
	public var polymodLibrary:PolymodAssetLibrary;
	public var modLibraries(default, null):Map<String, LimeModLibrary>;

	public function new()
	{
	}

	public function init(?params:FrameworkParams):Bool
	{
		// Get all the default asset libraries:
		var defaultLibraries = getDefaultAssetLibraries();

		modLibraries = new Map<String, LimeModLibrary>();

		var hasMoreThanDefault = false;
		for (key in defaultLibraries.keys())
		{
			if (key != "default")
			{
				hasMoreThanDefault = true;
				break;
			}
		}

		if (hasMoreThanDefault && params == null)
		{
			Polymod.error(PolymodErrorCode.LIME_MISSING_ASSET_LIBRARY_INFO,
				"Your Lime/OpenFL configuration is using custom asset libraries, but you have not provided any frameworkParams in Polymod.init() that tells Polymod which asset libraries to expect and what their mod sub-directory prefixes should be.",
				PolymodErrorOrigin.INIT);
			return false;
		}

		if (hasMoreThanDefault && params.assetLibraryPaths == null)
		{
			Polymod.error(PolymodErrorCode.LIME_MISSING_ASSET_LIBRARY_INFO,
				"Your Lime/OpenFL configuration is using custom asset libraries, but you have not provided the frameworkParams.assetLibraryPaths parameter in Polymod.init() that tells Polymod which asset libraries to expect and what their mod sub-directory prefixes should be.",
				PolymodErrorOrigin.INIT);
			return false;
		}

		// Wrap each asset library in `LimeModLibrary`, register it with Lime, and store it here
		for (key in defaultLibraries.keys())
		{
			var pathPrefix = "";
			if (hasMoreThanDefault)
			{
				if (!params.assetLibraryPaths.exists(key) && key != "default")
				{
					Polymod.error(PolymodErrorCode.LIME_MISSING_ASSET_LIBRARY_REFERENCE,
						"Your Lime/OpenFL configuration is using custom asset libraries, and you provided frameworkParams in Polymod.init(), but we couldn't find a match for this asset library: (" +
						key + ")",
						PolymodErrorOrigin.INIT);
					return false;
				}
				else
				{
					if (key == "default")
					{
						pathPrefix = "";
					}
					else
					{
						pathPrefix = params.assetLibraryPaths.get(key);
					}
				}
			}
			var fallbackLibrary = defaultLibraries.get(key);
			var modLibrary = getModLibrary(fallbackLibrary, pathPrefix);
			modLibraries.set(key, modLibrary);
		}

		for (key in modLibraries.keys())
		{
			Assets.registerLibrary(key, modLibraries.get(key));
		}

		return true;
	}

	private function getModLibrary(fallbackLibrary:AssetLibrary, pathPrefix:String):LimeModLibrary
	{
		return new LimeModLibrary(this, fallbackLibrary, pathPrefix);
	}

	public function destroy()
	{
		polymodLibrary = null;
		restoreDefaultAssetLibraries();
		for (key in modLibraries.keys())
		{
			var modLibrary = modLibraries.get(key);
			modLibrary.destroy();
			modLibraries.remove(key);
		}
		modLibraries = null;
	}

	public function exists(id:String):Bool
	{
		var symbol = new IdAndLibrary(id, modLibraries);
		var e = symbol.library.exists(symbol.modId, null);
		return e;
	}

	public function getBytes(id:String):Bytes
	{
		var symbol = new IdAndLibrary(id, modLibraries);
		var bytes = symbol.library.getBytes(symbol.modId);
		return bytes;
	}

	public function getText(id:String):String
	{
		var symbol = new IdAndLibrary(id, modLibraries);
		var text = symbol.library.getText(symbol.modId);
		return text;
	}

	public function getPath(id:String):String
	{
		var symbol = new IdAndLibrary(id, modLibraries);
		var path = symbol.library.getPath(symbol.modId);
		return path;
	}

	public function list(type:PolymodAssetType = null):Array<String>
	{
		var arr = [];
		for (modLibrary in modLibraries)
		{
			arr = arr.concat(modLibrary.list(type == null ? null : LimeModLibrary.PolyToLime(type)));
		}
		return arr;
	}

	public function clearCache()
	{
		if (defaultAssetLibraries != null)
		{
			for (key in Assets.cache.audio.keys())
			{
				Assets.cache.audio.remove(key);
			}
			for (key in Assets.cache.font.keys())
			{
				Assets.cache.font.remove(key);
			}
			for (key in Assets.cache.image.keys())
			{
				Assets.cache.image.remove(key);
			}
		}
	}

	public function stripAssetsPrefix(id:String):String
	{
		if (Util.uIndexOf(id, "assets/") == 0)
		{
			id = Util.uSubstring(id, 7);
		}
		return id;
	}
}

class LimeModLibrary extends AssetLibrary
{
	public static function LimeToPoly(type:AssetType):PolymodAssetType
	{
		return switch (type)
		{
			case AssetType.BINARY: PolymodAssetType.BYTES;
			case AssetType.FONT: PolymodAssetType.FONT;
			case AssetType.IMAGE: PolymodAssetType.IMAGE;
			case AssetType.MUSIC: PolymodAssetType.AUDIO_MUSIC;
			case AssetType.SOUND: PolymodAssetType.AUDIO_SOUND;
			case AssetType.MANIFEST: PolymodAssetType.MANIFEST;
			case AssetType.TEMPLATE: PolymodAssetType.TEMPLATE;
			case AssetType.TEXT: PolymodAssetType.TEXT;
			default: PolymodAssetType.UNKNOWN;
		}
	}

	public static function PolyToLime(type:PolymodAssetType):AssetType
	{
		return switch (type)
		{
			case PolymodAssetType.BYTES: AssetType.BINARY;
			case PolymodAssetType.FONT: AssetType.FONT;
			case PolymodAssetType.IMAGE: AssetType.IMAGE;
			case PolymodAssetType.AUDIO_MUSIC: AssetType.MUSIC;
			case PolymodAssetType.AUDIO_SOUND: AssetType.SOUND;
			case PolymodAssetType.AUDIO_GENERIC: AssetType.SOUND;
			case PolymodAssetType.MANIFEST: AssetType.MANIFEST;
			case PolymodAssetType.TEMPLATE: AssetType.TEMPLATE;
			case PolymodAssetType.TEXT: AssetType.TEXT;
			default: AssetType.BINARY;
		}
	}

	public var pathPrefix:String;

	var b:LimeBackend;
	var p:PolymodAssetLibrary;
	var fallback:AssetLibrary;
	var hasFallback:Bool;
	var type(default, null):Map<String, AssetType>;

	public function new(backend:LimeBackend, fallback:AssetLibrary, ?pathPrefix:String = "")
	{
		b = backend;
		p = b.polymodLibrary;
		this.pathPrefix = pathPrefix;
		this.fallback = fallback;
		hasFallback = this.fallback != null;
		super();
	}

	public function destroy()
	{
		b = null;
		p = null;
		fallback = null;
		type = null;
	}

	public override function getAsset(id:String, type:String):Dynamic
	{
		if (type == TEXT)
			return getText(id);

		var symbol = new IdAndLibrary(id, this);

		// Check for a modded asset.
		if (p.check(symbol.modId, LimeToPoly(cast type)))
		{
			// Load the modded asset.
			return super.getAsset(p.file(symbol.modId), type);
		}
		else if (hasFallback)
		{
			// Load the base asset.
			return fallback.getAsset(p.fileDefault(id), type);
		}
		// No fallback.
		return null;
	}

	public override function exists(id:String, type:String):Bool
	{
		var symbol = new IdAndLibrary(id, this);
		if (p.check(symbol.modId, LimeToPoly(cast type)))
		{
			// Found a modded asset.
			return true;
		}
		else if (hasFallback)
		{
			// Check the base asset.
			return p.checkDefault(symbol.modId, LimeToPoly(cast type));
		}
		// No fallback.
		return false;
	}

	public override function getAudioBuffer(id:String):AudioBuffer
	{
		var symbol = new IdAndLibrary(id, this);
		if (p.check(symbol.modId))
		{
			return AudioBuffer.fromBytes(p.fileSystem.getFileBytes(p.file(symbol.modId)));
		}
		else if (hasFallback)
		{
			return fallback.getAudioBuffer(p.fileDefault(id));
		}
		return null;
	}

	public override function getBytes(id:String):Bytes
	{
		var symbol = new IdAndLibrary(id, this);
		var file = p.file(symbol.modId);
		if (p.check(symbol.modId))
		{
			return p.fileSystem.getFileBytes(p.file(symbol.modId));
		}
		else if (hasFallback)
		{
			return fallback.getBytes(p.fileDefault(id));
		}
		return null;
	}

	public override function getFont(id:String):Font
	{
		var symbol = new IdAndLibrary(id, this);
		if (p.check(symbol.modId))
		{
			return Font.fromBytes(p.fileSystem.getFileBytes(p.file(symbol.modId)));
		}
		else if (hasFallback)
		{
			return fallback.getFont(p.fileDefault(id));
		}
		return null;
	}

	public override function getImage(id:String):Image
	{
		var symbol = new IdAndLibrary(id, this);
		if (p.check(symbol.modId))
		{
			return Image.fromBytes(p.fileSystem.getFileBytes(p.file(symbol.modId)));
		}
		else if (hasFallback)
		{
			return fallback.getImage(p.fileDefault(id));
		}
		return null;
	}

	public override function getPath(id:String):String
	{
		var symbol = new IdAndLibrary(id, this);
		if (p.check(symbol.modId))
		{
			return p.file(symbol.modId);
		}
		else if (hasFallback)
		{
			return fallback.getPath(p.fileDefault(id));
		}
		return null;
	}

	public override function getText(id:String):String
	{
		var symbol = new IdAndLibrary(id, this);
		var modText = null;
		if (p.check(symbol.modId))
		{
			modText = super.getText(symbol.modId);
		}
		else if (hasFallback)
		{
			modText = fallback.getText(p.fileDefault(id));
		}

		if (modText != null)
		{
			// TODO: Not implemented for non-default asset libraries
			modText = p.mergeAndAppendText(id, modText);
		}

		return modText;
	}

	public override function loadBytes(id:String):Future<Bytes>
	{
		var symbol = new IdAndLibrary(id, this);
		if (p.check(symbol.modId))
		{
			return Bytes.loadFromFile(p.file(symbol.modId));
		}
		else if (hasFallback)
		{
			return fallback.loadBytes(p.fileDefault(id));
		}
		return Bytes.loadFromFile("");
	}

	public override function loadFont(id:String):Future<Font>
	{
		var symbol = new IdAndLibrary(id, this);
		if (p.check(symbol.modId))
		{
			#if (js && html5)
			return Font.loadFromName(paths.get(p.file(symbol.modId)));
			#else
			return Font.loadFromFile(paths.get(p.file(symbol.modId)));
			#end
		}
		else if (hasFallback)
		{
			return fallback.loadFont(p.fileDefault(id));
		}
		#if (js && html5)
		return Font.loadFromName(paths.get(""));
		#else
		return Font.loadFromFile(paths.get(""));
		#end
	}

	public override function loadImage(id:String):Future<Image>
	{
		var symbol = new IdAndLibrary(id, this);
		if (p.check(symbol.modId))
		{
			return Image.loadFromFile(p.file(symbol.modId));
		}
		else if (hasFallback)
		{
			return fallback.loadImage(p.fileDefault(id));
		}
		return Image.loadFromFile("");
	}

	public override function loadAudioBuffer(id:String)
	{
		var symbol = new IdAndLibrary(id, this);
		if (p.check(symbol.modId))
		{
			if (pathGroups.exists(p.file(symbol.modId)))
			{
				return AudioBuffer.loadFromFiles(pathGroups.get(p.file(symbol.modId)));
			}
			else
			{
				return AudioBuffer.loadFromFile(paths.get(p.file(symbol.modId)));
			}
		}
		else if (hasFallback)
		{
			return fallback.loadAudioBuffer(p.fileDefault(id));
		}
		return AudioBuffer.loadFromFile("");
	}

	public override function loadText(id:String):Future<String>
	{
		var symbol = new IdAndLibrary(id, this);
		if (p.check(symbol.modId))
		{
			var request = new HTTPRequest<String>();
			return request.load(paths.get(p.file(symbol.modId)));
		}
		else if (hasFallback)
		{
			return fallback.loadText(p.fileDefault(id));
		}
		var request = new HTTPRequest<String>();
		return request.load("");
	}

	public override function isLocal(id:String, type:String):Bool
	{
		var symbol = new IdAndLibrary(id, this);
		if (p.check(symbol.modId))
		{
			return true;
		}
		else if (hasFallback)
		{
			return fallback.isLocal(p.fileDefault(id), type);
		}
		return false;
	}

	public override function list(type:String):Array<String>
	{
		var fallbackList = hasFallback ? fallback.list(type) : [];

		var requestedType = type != null ? cast(type, AssetType) : null;
		var items = [];

		for (id in p.type.keys())
		{
			if (id.indexOf(PolymodConfig.appendFolder) == 0 || id.indexOf(PolymodConfig.mergeFolder) == 0)
				continue;
			if (requestedType == null || exists(id, requestedType))
			{
				items.push(id);
			}
		}

		// Properly handle FireTongue assets.
		// We want to:
		// - Exclude any assets not in the current locale.
		// - Include any assets in the current locale's asset folder as though they were in the root asset folder.
		// - Include other assets (such as FireTongue data files) as though they were in the locale folder.
		for (fallbackId in fallbackList)
		{
			if (fallbackId.startsWith(p.rawTongueDirectory))
			{
				// Localized file (example: assets/locales/en-US/...)
				if (fallbackId.startsWith(p.localeAssetPrefix))
				{
					// Localized asset file in CURRENT locale! (example: assets/locales/en-US/assets/...)
					// We should register this with the locale path prefix removed.

					var assetId = Util.stripPathPrefix(fallbackId, p.localeAssetPrefix);
					if (fallbackId.startsWith('assets/'))
						assetId = Util.pathJoin('assets', assetId);
					if (items.indexOf(fallbackId) == -1)
					{
						if (requestedType == null || fallback.exists(fallbackId, type))
						{
							items.push(assetId);
							items.push(fallbackId);
						}
					}
				}
				else
				{
					// Localized FireTongue data file, or asset file in other locale! (example: assets/locales/en-US/data.tsv)

					var assetId = fallbackId;
					if (items.indexOf(assetId) == -1)
					{
						if (requestedType == null || fallback.exists(assetId, type))
						{
							items.push(assetId);
						}
					}
				}
			}
			else
			{
				// Unlocalized asset. Handle the original path.

				var assetId = fallbackId;
				if (items.indexOf(assetId) == -1)
				{
					if (requestedType == null || fallback.exists(assetId, type))
					{
						items.push(assetId);
					}
				}
			}
		}

		return items;
	}
}

/**
 * This helper class helps me deal with all the path nonsense of custom asset library asset calls
 * e.g. asking library "foo" for "bar.png" will result in:
 *   id = "foo:bar.png"
 *   lib = "foo"
 *   library = the "foo" library
 *   nakedId = "bar.png"
 *   modId = "foo/bar.png" (assuming "foo" is the mod path prefix for the "foo" library)
 *   fallbackId = "foo:bar.png" 
 */
private class IdAndLibrary
{
	public var library(default, null):LimeModLibrary;
	public var lib(default, null):String;
	public var modId(default, null):String;
	public var nakedId(default, null):String;
	public var fallbackId(default, null):String;

	public inline function new(id:String, ?libs:Map<String, LimeModLibrary>, ?l:LimeModLibrary)
	{
		fallbackId = id;
		var colonIndex = id.indexOf(":");
		lib = id.substring(0, colonIndex);
		nakedId = id.substring(colonIndex + 1);
		if (l != null)
		{
			library = l;
		}
		else if (libs != null)
		{
			if (lib == "" || lib == null)
			{
				lib = "default";
			}
			library = libs.get(lib);
		}
		if (library != null && library.pathPrefix != null && library.pathPrefix != "")
		{
			modId = library.pathPrefix + "/" + nakedId;
		}
		modId = nakedId;
	}
}
#end

#end
