module KoL.Api where

import Prelude hiding (read, catch)
import KoL.Util
import KoL.UtilTypes
import Control.Applicative
import Control.Exception
import Control.Monad
import Network.CGI (formEncode)
import Network.URI
import Text.JSON
import qualified Data.ByteString.Char8

getCharStatusObj ref = do
	Ok jscomb <- decodeStrict <$> readstatus ref
	let Ok jsobj = valFromObj "status" jscomb
	return jsobj

getInventoryObj ref = do
	Ok jscomb <- decodeStrict <$> readstatus ref
	let Ok jsobj = valFromObj "inventory" jscomb
	return jsobj

getInventoryCounts ref = do
	jsobj <- getInventoryObj ref
	let strcounts = fromJSObject jsobj
	let get_value name = i
		where i = case valFromObj name jsobj of
			Ok oki -> oki
			_ -> read_e j
				where Ok j = valFromObj name jsobj
	let counts = map (\(x, _y) -> (read_e x :: Integer, (get_value x) :: Integer)) strcounts
	return counts

data ApiInfo = ApiInfo {
	charName :: String,
	turnsplayed :: Integer,
	ascension :: Integer,
	daysthisrun :: Integer,
	pwd :: String
} -- deriving (Read, Show, Data, Typeable)

rawDecodeApiInfo jsontext = do
		ApiInfo { charName = getstr "name", turnsplayed = getnum "turnsplayed", ascension = getnum "ascensions" + 1, daysthisrun = getnum "daysthisrun", pwd = getstr "pwd" }
	where
		Ok jscomb = decodeStrict jsontext
		Ok jsobj = valFromObj "status" jscomb
		getstr what = case valFromObj what jsobj of
			Ok (JSString s) -> fromJSString s
			_ -> throw $ InternalError $ "Error parsing API text " ++ what
		getnum what = case valFromObj what jsobj of
			Ok (JSString s) -> jss where
				Just jss = read_as (fromJSString s)
			Ok (JSRational _ r) -> round r
--			Ok JSNull -> 0 -- HACK for when rollover is broken and not set yet. Removed, no longer relevant?
			_ -> throw $ InternalError $ "Error parsing API number " ++ what

getApiInfo ref = rawDecodeApiInfo <$> readstatus ref

getStatus ref = do
	jsonstatusinv <- nochangeGetPageRawNoScripts ("/api.php?what=status,inventory&for=kolproxy+" ++ kolproxy_version_number ++ "+by+Eleron&format=json") ref
	case decodeStrict jsonstatusinv :: Result (JSObject JSValue) of
		Ok _ -> return jsonstatusinv
		_ -> do
			putStrLn $ "Status+inventory API returned:\n  ===\n\n" ++ jsonstatusinv ++ "\n\n  ===\n\n"
			throwIO $ ApiPageException jsonstatusinv

-- TODO: Do this in Lua instead?
asyncGetItemInfoObj itemid ref = do
	f <- rawAsyncNochangeGetPageRawNoScripts ("/api.php?what=item&for=kolproxy+" ++ kolproxy_version_number ++ "+by+Eleron&format=json&id=" ++ show itemid) ref
	return $ do
		jsonobj <- Data.ByteString.Char8.unpack <$> f
		case decodeStrict jsonobj :: Result JSValue of
			Ok x -> return x
			_ -> do
				putStrLn $ "Item API returned:\n  ===\n\n" ++ jsonobj ++ "\n\n  ===\n\n"
				throwIO $ ApiPageException jsonobj



-- Not in server API! From old Info.hs

getPlayerId name ref = do
	ai <- getApiInfo ref
	text <- nochangeGetPageRawNoScripts ("/submitnewchat.php?" ++ (formEncode [("pwd", pwd ai), ("graf", "/whois " ++ name)])) ref
	return $ case matchGroups "<a target=mainpane href=\"showplayer.php\\?who=([0-9]+)\">" text of
		[[x]] -> Just y
			where
				Just y = read_as x :: Maybe Integer
		_ -> Nothing

-- TODO: Remove?
getRawCharpaneText ref = nochangeGetPageRawNoScripts "/charpane.php" ref



-- Downloading utility methods. TODO: put these elsewhere

postPageRawNoScripts url params ref = do
	(body, goturi, _) <- join $ fst <$> (rawRetrievePage ref) ref (mkuri url) (Just params)
	if ((uriPath goturi) == (uriPath $ mkuri url))
		then return body
		else do
			if uriPath goturi == "/login.php" || uriPath goturi == "/maint.php"
				then throwIO $ NotLoggedInException
				else do
					putStrLn $ "got uri: " ++ (show goturi) ++ " when raw-getting " ++ (url)
					throwIO $ UrlMismatchException url goturi

rawAsyncNochangeGetPageRawNoScripts url ref = do
	f <- fst <$> (nochangeRawRetrievePageFunc ref) ref (mkuri url) Nothing False
	return $ do
		(body, goturi, _) <- f
		if ((uriPath goturi) == (uriPath $ mkuri url))
			then return body
			else do
				if uriPath goturi == "/login.php" || uriPath goturi == "/maint.php"
					then throwIO $ NotLoggedInException
					else do
						putStrLn $ "got uri: " ++ (show goturi) ++ " when raw-getting " ++ (url)
						throwIO $ UrlMismatchException url goturi

nochangeGetPageRawNoScripts url ref = Data.ByteString.Char8.unpack <$> (join $ rawAsyncNochangeGetPageRawNoScripts url ref)