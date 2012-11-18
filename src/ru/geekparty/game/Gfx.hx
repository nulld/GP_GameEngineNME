package com.nevosoft.isoframework;

/**
 * ...
 * @author nulldivide
 */

import nme.display.BitmapData;
import com.nevosoft.utils.AsyncCommand;
import com.nevosoft.utils.AsyncCommandSequence;
import nme.geom.Rectangle;
import com.nevosoft.isoframework.ResourceManager;

typedef TSpriteSheet = {
	var name:String;
	var oX:Float;
	var oY:Float;
	var cols:Int;
	var rows:Int;
	var width:Float;
	var height:Float;
	var frameCount:Int;
	var frameWidth:Float;
	var frameHeight:Float;	
	var atlas:Int;
	var rect:Rectangle;
	var zIndex:Int;
}

typedef TAnimationFrame = {
	var index:Int;
	var x:Float;
	var y:Float;
	var rotation:Float;
	var scaleX:Float;
	var scaleY:Float;
	var spriteSheet:Int;
}

typedef TAnimationLayer = {
	var name:String;
	var frames:Array<TAnimationFrame>;
	var zIndex:Int;
}

typedef TAnimation = {
	var name:String;
	var fps:Int;
	var loopAt:Int;
	var frameCount:Int;
	var layers:Array<TAnimationLayer>;
}

class Gfx 
{	
	public var canvasWidth:Float;
	public var canvasHeight:Float;
	public var spriteSheets:Array<TSpriteSheet>;
	public var atlases:Array<BitmapData>;
	public var animations:Hash<TAnimation>;
	public var fps:Int;
	public var layersCount:Int;
	
	public var path:String;
	public var atlasPath:String;

	public function new(path:String, ?atlasPath:String) 
	{
		this.path = path;
		this.atlasPath = atlasPath;
		atlases = [];
		animations = new Hash<TAnimation>();
		spriteSheets = [];		
		fps = 12;
	}
	
	public function doLoad(complete_cb:Void->Void):Void
	{
		var cs:AsyncCommandSequence<Void, Void> = new AsyncCommandSequence<Void,Void>();		
		cs.Add(new AsyncCommand<Void, Void>(_parseSpiteSheets));
		cs.Add(new AsyncCommand<Void, Void>(_parseAnimations));
		
		
		cs.Execute( function():Void
 				   {					   
						complete_cb();						
				   });
	}
	
	public function getSpriteSheetNamed(name:String):Null<TSpriteSheet>
	{
		for (ss in spriteSheets)
		{
			if (ss.name == name) return ss;			
		}
		return null;
	}
	
	private function _parseSpiteSheets(complete_cb:(Void)->Void, input:Dynamic):Void
	{
	
		ResourceManager.instance().GetText(path + "/sheets.xml"
										  , function(result:String):Void
										  {	
											  
											var xml:Xml = Xml.parse(result);																						
											var atlasesHash:Hash<BitmapData> = new Hash<BitmapData>();
											
											//make all used atlases list
											for (sheet in xml.firstChild().elements())
											{	
												for (texture in sheet.elements())
												{													
													atlasesHash.set(texture.get("atlas"), null);			
												}
											}	
											
											var batch:Array<AssetGetTask> = [];
											var reIndexHash:Hash<Int> = new Hash<Int>();
											var i = 0;
											for (atlasUrl in atlasesHash.keys())
											{
												reIndexHash.set(atlasUrl, i++);
												batch.push( {
													url : ((atlasPath == null) ? path : atlasPath) + "/" + atlasUrl
													, type : ResourceManager.TYPE_BITMAP_DATA
													, data : null
												} );												
											}
											
											ResourceManager.instance().GetBatch(batch, function():Void
												{
													for (task in batch)
													{
														atlases.push(task.data);
													}
													
													//construct sprite sheets
													for (sheet in xml.firstChild().elements())
													{	
														for (texture in sheet.elements())
														{			
															var frameCount:Int = (texture.get("frameCount") == null) ? 1 : Std.parseInt(texture.get("frameCount"));
															var width:Float = Std.parseFloat(texture.get("width"));
															var height:Float = Std.parseFloat(texture.get("height"));
															var atlasWidth:Float = atlases[reIndexHash.get(texture.get("atlas"))].width;
															var atlasHeight:Float = atlases[reIndexHash.get(texture.get("atlas"))].height;
															
															var rect:Rectangle = new Rectangle( Std.parseFloat(texture.get("left")) * atlasWidth
																								, Std.parseFloat(texture.get("top")) * atlasHeight
																								, (Std.parseFloat(texture.get("right")) - Std.parseFloat(texture.get("left"))) * atlasWidth
																								, (Std.parseFloat(texture.get("bottom")) - Std.parseFloat(texture.get("top")))* atlasHeight );
															
															spriteSheets.push( {
																name : texture.get("name")
																, oX : Std.parseFloat(texture.get("registrationPointX"))
																, oY : Std.parseFloat(texture.get("registrationPointY"))																
																, width : width
																, height : height
																, frameCount : frameCount
																, frameWidth : (texture.get("frameWidth") == null) ? width : Std.parseFloat(texture.get("frameWidth"))
																, frameHeight : (texture.get("frameHeight") == null) ? height : Std.parseFloat(texture.get("frameHeight"))
																, cols : (texture.get("columns") == null) ? 1 : Std.parseInt(texture.get("columns"))
																, rows : (texture.get("rows") == null) ? 1 : Std.parseInt(texture.get("rows"))
																, atlas : reIndexHash.get(texture.get("atlas"))
																, rect  : rect
																, zIndex : (texture.get("zIndex") == null) ? 0 : Std.parseInt(texture.get("zIndex"))
															});	
															
														}
													}	
													
													
													complete_cb(null);
												});
											
											
										  });		
	}
	
	private function _parseAnimations(complete_cb:(Void)->Void, input:Dynamic):Void
	{
		layersCount = 0;
		ResourceManager.instance().GetText(path + "/animations.xml"
											, function(result:String):Void
											{	
												var xml:Xml = Xml.parse(result);
												for (anim in xml.firstChild().elements())
												{
													var layers:Array<TAnimationLayer> = [];
													
													for (part in anim.elements())
													{
														var frames:Array<TAnimationFrame> = [];
														var spriteSheet:TSpriteSheet = null;
														if (part.nodeName == "Part")
														{
															var spriteSheetIndex:Int = 0;
															var i = 0;																
															
															for (ss in spriteSheets)
															{													
																if (ss.name == part.get("name"))
																{																	
																	spriteSheet = ss;
																	spriteSheetIndex = i;
																	break;
																}
																i++;
															}
															
															for (frameConf in part.elements())
															{
																var frame:TAnimationFrame = {
																	index : Std.parseInt(frameConf.get("index"))
																	, x	  : (frameConf.get("x") == null) ? 0 : Std.parseFloat(frameConf.get("x"))
																	, y	  : (frameConf.get("y") == null) ? 0 : Std.parseFloat(frameConf.get("y"))
																	, rotation : (frameConf.get("rotation") == null) ? 0 : Std.parseFloat(frameConf.get("rotation"))
																	, scaleX   : (frameConf.get("scaleX") == null) ? 1 : Std.parseFloat(frameConf.get("scaleX"))
																	, scaleY   : (frameConf.get("scaleY") == null) ? 1 : Std.parseFloat(frameConf.get("scaleY"))
																	, spriteSheet : spriteSheetIndex
																};
																
																frames.push(frame);
															}
															
															if (frames.length > 0)
															{
																var layer:TAnimationLayer = {
																	name   : part.get("name")
																	, frames : frames
																	, zIndex : spriteSheets[spriteSheetIndex].zIndex
																};
																layers.push(layer);
															}
															
															
															
															if (layers.length > layersCount)
															{
																layersCount = layers.length;
															}
														}					
														
													}
													
													layers.sort(compareLayers);
													
													
													var animation:TAnimation = {
														name : anim.get("name")
														, fps : fps
														, loopAt : (anim.get("loopAt") == null) ? -1 : Std.parseInt( anim.get("loopAt") )
														, frameCount : Std.parseInt(anim.get("frameCount"))
														, layers : layers
													};
													animations.set(animation.name, animation);													
												}
											  
												complete_cb(null);
										  } );
	}
	
	private function compareLayers(a:TAnimationLayer, b:TAnimationLayer):Int
	{
		return (a.zIndex - b.zIndex);
	}
	
}