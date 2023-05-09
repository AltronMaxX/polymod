package polymod;

import polymod.format.JsonHelp;
import polymod.Polymod;

interface IModMetadata 
{
    /**
      * The internal ID of the mod.
      */
      public var id:String;
 
      /**
       * The human-readable name of the mod.
       */
      public var title:String;
  
      /**
       * A short description of the mod.
       */
      public var description:String;
  
      /**
       * A link to the homepage for a mod.
       * Should provide a URL where the mod can be downloaded from.
       */
      public var homepage:String;
  
      /**
       * A version number for the API used by the mod.
       * Used to prevent compatibility issues with mods when the application changes.
       */
      public var apiVersion:Version;
  
      /**
       * A version number for the mod itself.
       * Should be provided in the Semantic Versioning format.
       */
      public var modVersion:Version;
  
      /**
       * The name of a license determining the terms of use for the mod.
       */
      public var license:String;
  
      /**
       * Binary data containing information on the mod's icon file, if it exists.
       * This is useful when you want to display the mod's icon in your application's mod menu.
       */
      public var icon:Null<Bytes>;
  
      /**
       * The path on the filesystem to the mod's icon file.
       */
      public var iconPath:String;
  
      /**
       * The path where this mod's files are stored, on the IFileSystem.
       */
      public var modPath:String;
  
      /**
       * `metadata` provides an optional list of keys.
       * These can provide additional information about the mod, specific to your application.
       */
      public var metadata:Map<String, String>;
  
      /**
       * A list of dependencies.
       * These other mods must be also be loaded in order for this mod to load,
       * and this mod must be loaded after the dependencies. 
       */
      public var dependencies:ModDependencies;
  
      /**
       * A list of dependencies.
       * This mod must be loaded after the optional dependencies, 
       * but those mods do not necessarily need to be loaded.
       */
      public var optionalDependencies:ModDependencies;
  
      /**
       * A deprecated field representing the mod's author.
       * Please use the `contributors` field instead.
       */
      @:deprecated
      public var author(get, set):String;
  
      // author has been made a property so setting it internally doesn't throw deprecation warnings
      var _author:String;
  
      function get_author();
  
      function set_author(v):String;
  
      /**
       * A list of contributors to the mod.
       * Provides data about their roles as well as optional contact information.
       */
      public var contributors:Array<ModContributor>;

      public function toJsonStr():String;
}

/**
 * A type representing data about a mod, as retrieved from its metadata file.
 */
 class PolymodModMetadata implements IModMetadata
 {
     /**
      * The internal ID of the mod.
      */
     public var id:String;
 
     /**
      * The human-readable name of the mod.
      */
     public var title:String;
 
     /**
      * A short description of the mod.
      */
     public var description:String;
 
     /**
      * A link to the homepage for a mod.
      * Should provide a URL where the mod can be downloaded from.
      */
     public var homepage:String;
 
     /**
      * A version number for the API used by the mod.
      * Used to prevent compatibility issues with mods when the application changes.
      */
     public var apiVersion:Version;
 
     /**
      * A version number for the mod itself.
      * Should be provided in the Semantic Versioning format.
      */
     public var modVersion:Version;
 
     /**
      * The name of a license determining the terms of use for the mod.
      */
     public var license:String;
 
     /**
      * Binary data containing information on the mod's icon file, if it exists.
      * This is useful when you want to display the mod's icon in your application's mod menu.
      */
     public var icon:Bytes = null;
 
     /**
      * The path on the filesystem to the mod's icon file.
      */
     public var iconPath:String;
 
     /**
      * The path where this mod's files are stored, on the IFileSystem.
      */
     public var modPath:String;
 
     /**
      * `metadata` provides an optional list of keys.
      * These can provide additional information about the mod, specific to your application.
      */
     public var metadata:Map<String, String>;
 
     /**
      * A list of dependencies.
      * These other mods must be also be loaded in order for this mod to load,
      * and this mod must be loaded after the dependencies. 
      */
     public var dependencies:ModDependencies;
 
     /**
      * A list of dependencies.
      * This mod must be loaded after the optional dependencies, 
      * but those mods do not necessarily need to be loaded.
      */
     public var optionalDependencies:ModDependencies;
 
     /**
      * A deprecated field representing the mod's author.
      * Please use the `contributors` field instead.
      */
     @:deprecated
     public var author(get, set):String;
 
     // author has been made a property so setting it internally doesn't throw deprecation warnings
     var _author:String;
 
     function get_author()
     {
         if (contributors.length > 0)
         {
             return contributors[0].name;
         }
         return _author;
     }
 
     function set_author(v):String
     {
         if (contributors.length == 0)
         {
             contributors.push({name: v});
         }
         else
         {
             contributors[0].name = v;
         }
         return v;
     }
 
     /**
      * A list of contributors to the mod.
      * Provides data about their roles as well as optional contact information.
      */
     public var contributors:Array<ModContributor>;
 
     public function new()
     {
         // No-op constructor.
     }
 
     public function toJsonStr():String
     {
         var json = {};
         Reflect.setField(json, 'title', title);
         Reflect.setField(json, 'description', description);
         // Reflect.setField(json, 'author', _author);
         Reflect.setField(json, 'contributors', contributors);
         Reflect.setField(json, 'homepage', homepage);
         Reflect.setField(json, 'api_version', apiVersion.toString());
         Reflect.setField(json, 'mod_version', modVersion.toString());
         Reflect.setField(json, 'license', license);
         var meta = {};
         for (key in metadata.keys())
         {
             Reflect.setField(meta, key, metadata.get(key));
         }
         Reflect.setField(json, 'metadata', meta);
         return Json.stringify(json, null, '    ');
     }

     static final defaultMetadataVars:Array<String> = ['title', 'description', 'contributors', 'mod_version', 'api_version'];
 
     public static function fromJsonStr(str:String, ?metadataClass:Class<IModMetadata>):IModMetadata 
     {
         if (str == null || str == '')
         {
             Polymod.error(PARSE_MOD_META, 'Error parsing mod metadata file, was null or empty.');
             return null;
         }
 
         var json = null;
         try
         {
             json = haxe.Json.parse(str);
         }
         catch (msg:Dynamic)
         {
             Polymod.error(PARSE_MOD_META, 'Error parsing mod metadata file: (${msg})');
             return null;
         }

         var m:IModMetadata = metadataClass == null ? new ModMetadata() : Type.createInstance(metadataClass);
         m.title = JsonHelp.str(json, 'title');
         m.description = JsonHelp.str(json, 'description');
         m.contributors = JsonHelp.arrType(json, 'contributors');
         var apiVersionStr = JsonHelp.str(json, 'api_version');
         var modVersionStr = JsonHelp.str(json, 'mod_version');
         try
         {
            m.apiVersion = apiVersionStr;
         }
         catch (msg:Dynamic)
         {
            Polymod.error(PARSE_MOD_API_VERSION, 'Error parsing API version: (${msg}) ${PolymodConfig.modMetadataFile} was ${str}');
            return null;
         }
         try
         {
             m.modVersion = modVersionStr;
         }
         catch (msg:Dynamic)
         {
            Polymod.error(PARSE_MOD_VERSION, 'Error parsing mod version: (${msg}) ${PolymodConfig.modMetadataFile} was ${str}');
            return null;
         }
        if (metadataClass != null)
        {
            var jsonFields = Reflect.fields(json);
            for (field in jsonFields)
            {
                //Skip default vars
                if (defaultMetadataVars.concat(field))
                    continue;

                if (Reflect.hasField(m, field))
                {
                    try{
                        var fieldType = Type.typeof(Reflect.field(m, field));
                        var setField = cast (Reflect.getProperty(json, jsonFields), $fieldType);
                        Reflect.setField(m, field, Reflect.getProperty(json, jsonFields));
                    }
                }
            }
        }
        else
        {
            m._author = JsonHelp.str(json, 'author');
            m.homepage = JsonHelp.str(json, 'homepage');
            m.license = JsonHelp.str(json, 'license');
            m.metadata = JsonHelp.mapStr(json, 'metadata');
    
            m.dependencies = JsonHelp.mapVersionRule(json, 'dependencies');
            m.optionalDependencies = JsonHelp.mapVersionRule(json, 'optionalDependencies');
        }

         return m;
     }
 }