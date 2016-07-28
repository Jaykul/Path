using System;
using System.ComponentModel;
using System.Management.Automation;
using System.Collections.ObjectModel;
using System.Collections.Generic;
using System.Text.RegularExpressions;

[AttributeUsage(AttributeTargets.Field | AttributeTargets.Property)]
public class PathAttribute : ArgumentTransformationAttribute {

   public enum PathType { Simple, Provider, Drive, Relative }

   public PathType Type { get; set; }

   public override string ToString() {
      return "[Path(" + ((Type != PathType.Simple) ? "Type=\"" + Type + "\")]" : ")]");
   }

   public override Object Transform( EngineIntrinsics engine, Object inputData) {
      // standard workaround for the initial bind when pipeline data hasn't arrived
      if(inputData == null) {  return null; }

      ProviderInfo provider = null;
      PSDriveInfo drive = null;
      Collection<string> results = new Collection<string>();
      Collection<string> providerPaths = new Collection<string>();
      var PSPath = engine.SessionState.Path;
      var inputPaths = new Collection<string>();

      try {
         // in order to not duplicate code, always treat it as an object array
         var inputArray = inputData as object[];
         if(inputArray == null) { inputArray = new object[]{inputData}; }


         foreach(var input in inputArray) {
            // work around ToString() problem in FileSystemInfo
            var fsi = input as System.IO.FileSystemInfo;
            if(fsi != null) {
               inputPaths.Add(fsi.FullName);
            } else {
               // work around FileSystemInfo actually being a PSObject
               var psO = input as System.Management.Automation.PSObject;
               if(psO != null) {
                  fsi = psO.BaseObject as System.IO.FileSystemInfo;
                  if(fsi != null) {
                     inputPaths.Add(fsi.FullName);
                  } else {
                     inputPaths.Add(psO.BaseObject.ToString());
                  }
               } else {
                  inputPaths.Add(input.ToString());
               }
            }
         }

         foreach(string inputPath in inputPaths) {

            if(WildcardPattern.ContainsWildcardCharacters(inputPath)) {
               providerPaths = PSPath.GetResolvedProviderPathFromPSPath(inputPath, out provider);
            } else {
               providerPaths.Add(PSPath.GetUnresolvedProviderPathFromPSPath(inputPath, out provider, out drive));
            }

            foreach(string path in providerPaths) {
               var newPath = path;

               if(Type == PathType.Provider && !PSPath.IsProviderQualified(newPath)) {
                  newPath = provider.Name + "::" + newPath;
               } 
               else if(Type != PathType.Provider && PSPath.IsProviderQualified(newPath)) 
               {
                  newPath = Regex.Replace( newPath, Regex.Escape( provider.Name + "::" ), "");
               }

               if(Type == PathType.Drive) 
               {
                  string driveName;
                  if(!PSPath.IsPSAbsolute(newPath, out driveName)) {
                     if(drive == null) {
                        newPath = PSPath.GetUnresolvedProviderPathFromPSPath(newPath, out provider, out drive);
                     }
                     if(!PSPath.IsPSAbsolute(newPath, out driveName)) {
                        newPath = drive.Name + ":\\" + PSPath.NormalizeRelativePath( newPath, drive.Root );
                     }
                  }
               } else if(Type == PathType.Relative) {
                  var currentPath = PSPath.CurrentProviderLocation(provider.Name).ProviderPath.TrimEnd(new[]{'\\','/'});
                  var relativePath = Regex.Replace(newPath, "^" + Regex.Escape(currentPath), "", RegexOptions.IgnoreCase);
                  // Console.WriteLine("currentPath: " + currentPath + "  || relativePath: " + relativePath);
                  if(relativePath != newPath) {
                     newPath = ".\\" + relativePath.TrimStart(new[]{'\\'});
                  } else {
                     try {
                        newPath = PSPath.NormalizeRelativePath(newPath, currentPath);
                        // Console.WriteLine("currentPath: " + currentPath + "  || relativePath: " + relativePath + "  || newPath: " + newPath);
                     } catch {
                        newPath = relativePath;
                     }
                  }
               }

               results.Add(newPath);
            }
         }
      } catch (ArgumentTransformationMetadataException) {
         throw;
      } catch (Exception e) {
         throw new ArgumentTransformationMetadataException(string.Format("Cannot determine path ('{0}'). See $Error[0].Exception.InnerException.InnerException for more details.",e.Message), e);
      }
      return results;
   }
}