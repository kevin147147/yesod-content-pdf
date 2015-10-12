-- | Utilities for serving PDF from Yesod.
--   Uses and depends on command line utility wkhtmltopdf to render PDF from HTML.
module Yesod.Content.PDF
  ( -- * Conversion
    uri2PDF
  , html2PDF
    -- * Data type
  , PDF(..)
  , typePDF
  ) where

import Blaze.ByteString.Builder.ByteString
import Control.Monad.IO.Class (MonadIO(..))
import Data.ByteString
import Data.Conduit
import Network.URI
import System.IO
import System.IO.Temp
import System.Process
import Text.Blaze.Html
import Text.Blaze.Html.Renderer.String
import Yesod.Core.Content

newtype PDF = PDF ByteString

-- | Provide MIME type "application/pdf" as a ContentType for Yesod.
typePDF :: ContentType
typePDF = "application/pdf"

instance HasContentType PDF where
  getContentType _ = typePDF

instance ToTypedContent PDF where
  toTypedContent = TypedContent typePDF . toContent

instance ToContent PDF where
  toContent (PDF bs) = ContentSource $ do
    yield $ Chunk $ fromByteString bs

-- | Use wkhtmltopdf to render a PDF given the URI pointing to an HTML document.
uri2PDF :: MonadIO m => URI -> m PDF
uri2PDF uri = liftIO $ withSystemTempFile "output.pdf" $ uri2PDF' uri
  where
    uri2PDF' :: URI -> FilePath -> Handle -> IO PDF
    uri2PDF' uri' tempPDFFile tempHandle = do
      hClose tempHandle
      (_,_,_, pHandle) <- createProcess (proc "wkhtmltopdf" ["--quiet", show uri', tempPDFFile])
      _ <- waitForProcess pHandle
      PDF <$> Data.ByteString.readFile tempPDFFile

-- | Use wkhtmltopdf to render a PDF from an HTML (Text.Blaze.Html) type.
html2PDF :: MonadIO m => Html -> m PDF
html2PDF html = liftIO $ withSystemTempFile "output.pdf" (html2PDF' html)
  where
    html2PDF' :: Html -> FilePath -> Handle -> IO PDF
    html2PDF' html' tempPDFFile tempPDFHandle = do
      hClose tempPDFHandle
      withSystemTempFile "input.html" $ \tempHtmlFile tempHtmlHandle -> do
        System.IO.hPutStrLn tempHtmlHandle $ renderHtml html'
        hClose tempHtmlHandle
        (_,_,_, pHandle) <- createProcess (proc "wkhtmltopdf" ["--quiet", tempHtmlFile, tempPDFFile])
        _ <- waitForProcess pHandle
        PDF <$> Data.ByteString.readFile tempPDFFile
