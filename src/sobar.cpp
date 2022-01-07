#define sbr_BUILD_LIBRARY
#define NOMINMAX

#include <stdexcept>
#include <cstring>

#include "public/fpdfview.h"

#include "core/fpdfapi/parser/cpdf_document.h"
#include "fpdfsdk/cpdfsdk_helpers.h"

typedef std::shared_ptr<const class PdfDocument> *sbr_PdfDocument;
typedef std::shared_ptr<const class PdfPage> *sbr_PdfPage;
typedef std::shared_ptr<class PdfBitmap> *sbr_PdfBitmap;
typedef class CPDF_TextPage *sbr_PdfText;

#include "sobar.h"

template <typename T>
std::shared_ptr<T> &nullCheck(std::shared_ptr<T> *p)
{
	if (!p)
		throw std::invalid_argument("The argument is null.");
	return *p;
}

//----------------------------------------------------------------------------
class PdfDataAccess
{
public:
	PdfDataAccess() : _access({0, s_read, this}) {}

	virtual ~PdfDataAccess() {}
	virtual int read(unsigned long position, unsigned char *pBuf, unsigned long size) = 0;
	virtual unsigned long getSize() const = 0;

	FPDF_FILEACCESS *getFPDF_FILEACCESS() const
	{
		_access.m_FileLen = getSize();
		return const_cast<FPDF_FILEACCESS *>(&_access);
	}

private:
	mutable FPDF_FILEACCESS _access;

	static int s_read(void *param, unsigned long position, unsigned char *pBuf, unsigned long size)
	{
		return reinterpret_cast<PdfDataAccess *>(param)->read(position, pBuf, size);
	}
};

//----------------------------------------------------------------------------
class PdfCustomAccess : public PdfDataAccess
{
public:
	PdfCustomAccess(void *context, unsigned int size, sbr_ContextReadCallback read, sbr_ContextReleaseCallback release) : _context(context), _size(size), _read(read), _release(release)
	{
	}

	virtual ~PdfCustomAccess()
	{
		if (_release)
			_release(_context);
	}

	virtual int read(unsigned long position, unsigned char *pBuf, unsigned long size)
	{
		return _read(_context, pBuf, position, size);
	}

	virtual unsigned long getSize() const { return _size; }

private:
	void *_context;
	unsigned int _size;
	sbr_ContextReadCallback _read;
	sbr_ContextReleaseCallback _release;
};

#if defined(_WIN32)
#include <windows.h>

//----------------------------------------------------------------------------
class PdfFileAccessWindows : public PdfDataAccess
{
public:
	explicit PdfFileAccessWindows(const char *fileNameUtf8)
	{
		auto size = MultiByteToWideChar(CP_UTF8, 0, fileNameUtf8, -1, nullptr, 0);
		std::vector<WCHAR> buf;
		buf.resize(size);
		MultiByteToWideChar(CP_UTF8, 0, fileNameUtf8, -1, &buf[0], size);

		_handle = CreateFileW(&buf[0], GENERIC_READ, 0, nullptr, OPEN_EXISTING, 0, nullptr);
		if (_handle == INVALID_HANDLE_VALUE)
			throw std::runtime_error("Could not open file.");
	}

	virtual ~PdfFileAccessWindows()
	{
		if (_handle != nullptr && _handle != INVALID_HANDLE_VALUE)
			CloseHandle(_handle);
	}

	virtual int read(unsigned long position, unsigned char *pBuf, unsigned long size)
	{
		LARGE_INTEGER li;
		li.QuadPart = position;
		SetFilePointer(_handle, li.LowPart, &li.HighPart, FILE_BEGIN);
		DWORD dwRead;
		if (!ReadFile(_handle, pBuf, size, &dwRead, nullptr))
			return 0;
		return static_cast<int>(dwRead);
	}

	virtual unsigned long getSize() const
	{
		LARGE_INTEGER li;
		if (GetFileSizeEx(_handle, &li))
			return static_cast<unsigned long>(li.QuadPart);
		return 0;
	}

private:
	mutable HANDLE _handle;
};
#endif

//----------------------------------------------------------------------------
class PdfDocument
{
public:
	PdfDocument(const std::shared_ptr<PdfDataAccess> &fileAccess, const char *password) : m_fa(fileAccess)
	{
		m_doc = FPDF_LoadCustomDocument(m_fa->getFPDF_FILEACCESS(), password);
		if (!m_doc)
			throw std::runtime_error("FPDF_LoadCustomDocument failed.");
	}

	PdfDocument(const char *fileNameUtf8, const char *password)
	{
		m_doc = FPDF_LoadDocument(fileNameUtf8, password);
		if (!m_doc)
			throw std::runtime_error("FPDF_LoadDocument failed.");
	}

	PdfDocument(const void *data, size_t size, const char *password)
	{
		m_doc = FPDF_LoadMemDocument(data, static_cast<int>(size), password);
		if (!m_doc)
			throw std::runtime_error("FPDF_LoadDocument failed.");
	}

	virtual ~PdfDocument()
	{
		if (m_doc)
		{
			FPDF_CloseDocument(m_doc);
			m_doc = nullptr;
		}
	}

	size_t getPageCount() const { return FPDF_GetPageCount(m_doc); }

	FPDF_DOCUMENT getFPDF_DOCUMENT() const { return m_doc; }

	CPDF_Document *getCPDF_Document() const { return CPDFDocumentFromFPDFDocument(m_doc); }

private:
	std::shared_ptr<PdfDataAccess> m_fa;
	mutable FPDF_DOCUMENT m_doc;

	PdfDocument() = delete;
	PdfDocument(const PdfDocument &) = delete;
	PdfDocument &operator=(const PdfDocument &) = delete;
};

//----------------------------------------------------------------------------
class PdfBitmap
{
public:
	PdfBitmap(int width, int height, sbr_PixelFormat format, long stride,
			  void *scan0, sbr_PdfBitmapOnReleaseCallback callback, void *context)
		: m_buffer(nullptr)
	{
		if (width <= 0)
			throw std::invalid_argument("width must be positive integer value.");
		if (height <= 0)
			throw std::invalid_argument("height must be positive integer value.");

		if (!stride)
		{
			if (scan0)
				throw std::invalid_argument("stride must not be 0.");
			else
				stride = ((width * pixmapTypeToBpp(format)) + 3) & ~3;
		}

		if (!scan0)
			scan0 = m_buffer = new uint8_t[stride * height];

		m_format = format;
		m_bmp = FPDFBitmap_CreateEx(
			width, height, pixmapTypeToFPDFBitmapType(format), scan0, stride);
		if (!m_bmp)
			throw std::invalid_argument("FPDFBitmap_CreateEx failed.");

		m_callback = callback;
		m_context = context;
	}

	virtual ~PdfBitmap()
	{
		if (m_callback)
			m_callback(m_context);

		if (m_bmp)
			FPDFBitmap_Destroy(m_bmp);
		if (m_buffer)
			delete[] m_buffer;
	}

	FPDF_BITMAP getBitmap() const { return m_bmp; }

	void whiteFill()
	{
		auto lineSize = pixmapTypeToBpp(m_format) * getWidth();
		auto stride = getStride();
		auto h = getHeight();
		auto p = getBuffer();
		for (int i = 0; i < h; i++)
		{
			std::memset(p, 0xff, lineSize);
			p += stride;
		}
	}

	sbr_PixelFormat getPixelFormat() const { return m_format; }
	uint8_t *getBuffer() const { return static_cast<uint8_t *>(FPDFBitmap_GetBuffer(m_bmp)); }
	int getStride() const { return FPDFBitmap_GetStride(m_bmp); }
	int getWidth() const { return FPDFBitmap_GetWidth(m_bmp); }
	int getHeight() const { return FPDFBitmap_GetHeight(m_bmp); }
	bool doesNeedByteSwap() const
	{
		return m_format == sbr_PixelFormat_rgb || m_format == sbr_PixelFormat_rgba;
	}

private:
	sbr_PixelFormat m_format;
	mutable FPDF_BITMAP m_bmp;
	mutable uint8_t *m_buffer;
	sbr_PdfBitmapOnReleaseCallback m_callback;
	void *m_context;

	static int pixmapTypeToFPDFBitmapType(sbr_PixelFormat type)
	{
		switch (type)
		{
		case sbr_PixelFormat_gray:
			return FPDFBitmap_Gray;
		case sbr_PixelFormat_bgr:
			return FPDFBitmap_BGR;
		case sbr_PixelFormat_bgra:
			return FPDFBitmap_BGRA;
		case sbr_PixelFormat_rgb:
			return FPDFBitmap_BGR; // see doesNeedByteSwap
		case sbr_PixelFormat_rgba:
			return FPDFBitmap_BGRA; // see doesNeedByteSwap
		default:
			throw std::invalid_argument("Invalid pixel format.");
		}
	}

	static int pixmapTypeToBpp(sbr_PixelFormat type)
	{
		switch (type)
		{
		case sbr_PixelFormat_gray:
			return 1;
		case sbr_PixelFormat_bgr:
			return 3;
		case sbr_PixelFormat_bgra:
			return 4;
		case sbr_PixelFormat_rgb:
			return 3;
		case sbr_PixelFormat_rgba:
			return 4;
		default:
			throw std::invalid_argument("Invalid pixel format.");
		}
	}
};

//----------------------------------------------------------------------------
class PdfPage
{
public:
	PdfPage(const std::shared_ptr<const PdfDocument> &doc, FPDF_PAGE page)
		: m_doc(&doc)
	{
		m_page = page;
	}

	virtual ~PdfPage()
	{
		if (m_page)
		{
			FPDF_ClosePage(m_page);
			m_page = nullptr;
		}
	}

	double getWidth() const { return FPDF_GetPageWidth(m_page); }
	double getHeight() const { return FPDF_GetPageHeight(m_page); }
	const std::shared_ptr<const PdfDocument> &getDocument() const { return *m_doc; }
	FPDF_PAGE getFPDF_PAGE() const { return m_page; }
	CPDF_Page *getPage() const { return CPDFPageFromFPDFPage(m_page); }

	void render(std::shared_ptr<PdfBitmap> &bmp, int x, int y, int width, int height, sbr_RotateClockwise rotate, int flags) const
	{
		auto pf = bmp->getPixelFormat();
		if (pf != sbr_PixelFormat_bgra && pf != sbr_PixelFormat_rgba)
		{
			if (flags & sbr_rfNoWhiteFill)
			{
				flags &= ~sbr_rfNoWhiteFill;
			}
			else
			{
				bmp->whiteFill();
			}
		}

		FPDF_RenderPageBitmap(bmp->getBitmap(), m_page, x, y, width, height, static_cast<int>(rotate), configureFlags(bmp, flags));
	}

private:
	const std::shared_ptr<const PdfDocument> *m_doc;
	mutable FPDF_PAGE m_page;

	PdfPage() = delete;
	PdfPage(const PdfPage &) = delete;
	PdfPage &operator=(const PdfPage &) = delete;

	static int configureFlags(std::shared_ptr<PdfBitmap> &bmp, int flags)
	{
		auto f = flags;
		if (bmp->doesNeedByteSwap())
			f |= FPDF_REVERSE_BYTE_ORDER;
		return f;
	}
};

//--------------------------------------------------------------------------
template <class T, class... Args>
std::shared_ptr<const T> *newHandle(Args &&...args)
{
	return new std::shared_ptr<const T>(std::make_shared<T>(args...));
}

//--------------------------------------------------------------------------
sbr_EXPORT void sbr_API sbr_Initialize()
{
	FPDF_InitLibrary();
}
sbr_EXPORT void sbr_API sbr_Finalize()
{
	FPDF_DestroyLibrary();
}

sbr_EXPORT sbr_PdfDocument sbr_API sbr_PdfDocumentOpenFile(
	const char *utf8FileName, const char *utf8Password)
{
	try
	{
#if defined(_WIN32)
		return newHandle<PdfDocument>(std::make_shared<PdfFileAccessWindows>(utf8FileName), utf8Password);
#else
		return newHandle<PdfDocument>(utf8FileName, utf8Password);
#endif
	}
	catch (...)
	{
		return nullptr;
	}
}

sbr_EXPORT sbr_PdfDocument sbr_API sbr_PdfDocumentOpenMemory(
	const void *data, unsigned int size, const char *utf8Password)
{
	try
	{
		return newHandle<PdfDocument>(data, size, utf8Password);
	}
	catch (...)
	{
		return nullptr;
	}
}

sbr_EXPORT sbr_PdfDocument sbr_API sbr_PdfDocumentOpenCustom(
	void *context, unsigned int size, sbr_ContextReadCallback read, sbr_ContextReleaseCallback release, const char *utf8Password)
{
	try
	{
		return newHandle<PdfDocument>(std::make_shared<PdfCustomAccess>(context, size, read, release), utf8Password);
	}
	catch (...)
	{
		return nullptr;
	}
}

sbr_EXPORT void sbr_API sbr_PdfDocumentClose(sbr_PdfDocument doc)
{
	try
	{
		delete doc;
	}
	catch (...)
	{
	}
}

sbr_EXPORT int sbr_API sbr_PdfDocumentGetPageCount(sbr_PdfDocument doc)
{
	try
	{
		return static_cast<int>(nullCheck(doc)->getPageCount());
	}
	catch (...)
	{
		return 0;
	}
}

sbr_EXPORT sbr_PdfPage sbr_API sbr_PdfDocumentLoadPage(sbr_PdfDocument doc, int pageIndex)
{
	try
	{
		auto &d = nullCheck(doc);
		auto count = d->getPageCount();
		if (pageIndex < 0 || pageIndex >= count)
			throw std::invalid_argument("pageIndex out of range.");

		auto page = FPDF_LoadPage(d->getFPDF_DOCUMENT(), pageIndex);
		if (!page)
			throw std::runtime_error("FPDF_LoadPage failed.");

		return new std::shared_ptr<const PdfPage>(new PdfPage(d, page));
	}
	catch (...)
	{
		return nullptr;
	}
}

sbr_EXPORT void sbr_API sbr_PdfPageClose(sbr_PdfPage page)
{
	delete page;
}

sbr_EXPORT double sbr_API sbr_PdfPageGetWidth(sbr_PdfPage page)
{
	try
	{
		return nullCheck(page)->getWidth();
	}
	catch (...)
	{
		return 0;
	}
}

sbr_EXPORT double sbr_API sbr_PdfPageGetHeight(sbr_PdfPage page)
{
	try
	{
		return nullCheck(page)->getHeight();
	}
	catch (...)
	{
		return 0;
	}
}

// Get page rotation in clockwise direction. It returns either 0, 90, 180, or
// 270.
sbr_EXPORT int sbr_API sbr_PdfPageGetRotation(sbr_PdfPage page)
{
	try
	{
		return nullCheck(page)->getPage()->GetPageRotation();
	}
	catch (...)
	{
		return 0;
	}
}

sbr_EXPORT int sbr_API sbr_PdfPageRender(sbr_PdfPage page,
										 sbr_PdfBitmap bmp, int x, int y,
										 int width, int height,
										 sbr_RotateClockwise rotate,
										 int flags)
{
	try
	{
		auto &p = nullCheck(page);
		auto &pbmp = nullCheck(bmp);
		p->render(pbmp, x, y, width, height, rotate, flags);
		return 0;
	}
	catch (...)
	{
		return -1;
	}
}

sbr_EXPORT sbr_PdfBitmap sbr_API sbr_PdfBitmapCreate(
	int width, int height, sbr_PixelFormat format, long stride, void *scan0,
	sbr_PdfBitmapOnReleaseCallback callback, void *context)
{
	try
	{
		if (!stride && !scan0 && !callback && !context)
		{
			static const int bpp[] = {0, 1, 3, 4, 3, 4};
			stride = width * bpp[format];
			scan0 = new unsigned char[stride * height];
			callback = [](void *ptr)
			{ delete[] reinterpret_cast<unsigned char *>(ptr); };
			context = scan0;
		}

		return new std::shared_ptr<PdfBitmap>(
			new PdfBitmap(width, height, format, stride, scan0, callback, context));
	}
	catch (...)
	{
		return nullptr;
	}
}

sbr_EXPORT void sbr_API sbr_PdfBitmapRelease(sbr_PdfBitmap bmp)
{
	try
	{
		delete bmp;
	}
	catch (...)
	{
	}
}

sbr_EXPORT sbr_PixelFormat sbr_API sbr_PdfBitmapGetPixelFormat(sbr_PdfBitmap bmp)
{
	try
	{
		return nullCheck(bmp)->getPixelFormat();
	}
	catch (...)
	{
		return sbr_PixelFormat_invalid;
	}
}

sbr_EXPORT unsigned char *sbr_API sbr_PdfBitmapGetScan0Pointer(sbr_PdfBitmap bmp)
{
	try
	{
		return nullCheck(bmp)->getBuffer();
	}
	catch (...)
	{
		return nullptr;
	}
}

sbr_EXPORT long sbr_API sbr_PdfBitmapGetStride(sbr_PdfBitmap bmp)
{
	try
	{
		return nullCheck(bmp)->getStride();
	}
	catch (...)
	{
		return 0;
	}
}

sbr_EXPORT int sbr_API sbr_PdfBitmapGetWidth(sbr_PdfBitmap bmp)
{
	try
	{
		return nullCheck(bmp)->getWidth();
	}
	catch (...)
	{
		return 0;
	}
}

sbr_EXPORT int sbr_API sbr_PdfBitmapGetHeight(sbr_PdfBitmap bmp)
{
	try
	{
		return nullCheck(bmp)->getHeight();
	}
	catch (...)
	{
		return 0;
	}
}

#if defined(_WIN32)
#define generic_strdup _strdup
#else
#define generic_strdup strdup
#endif

static const char *EMPTY_STRING = "";

sbr_EXPORT void sbr_API sbr_PdfStringRelease(const char *str)
{
	if (str != EMPTY_STRING)
		free(static_cast<void *>(const_cast<char *>(str)));
}

#include "public/fpdf_text.h"
#include "core/fpdftext/cpdf_textpage.h"

sbr_EXPORT
	sbr_PdfText sbr_API
	sbr_PdfTextLoadFromPage(sbr_PdfPage page)
{
	try
	{
		auto &ap = nullCheck(page);
		return reinterpret_cast<sbr_PdfText>(FPDFText_LoadPage(ap->getFPDF_PAGE()));
	}
	catch (...)
	{
		return nullptr;
	}
}

static sbr_PdfText nullCheck(sbr_PdfText p)
{
	if (!p)
		throw std::invalid_argument("text argument is null.");
	return p;
}

static sbr_PdfRect &nullCheck(sbr_PdfRect *p)
{
	if (!p)
		throw std::invalid_argument("rect argument is null.");
	return *p;
}

static sbr_PdfCharInfo &nullCheck(sbr_PdfCharInfo *p)
{
	if (!p)
		throw std::invalid_argument("charInfo argument is null.");
	return *p;
}

sbr_EXPORT int sbr_API
sbr_PdfTextClose(sbr_PdfText text)
{
	FPDFText_ClosePage(reinterpret_cast<FPDF_TEXTPAGE>(text));
	return 0;
}

sbr_EXPORT int sbr_API sbr_PdfTextGetLength(sbr_PdfText text)
{
	try
	{
		return nullCheck(text)->CountChars();
	}
	catch (...)
	{
		return -1;
	}
}

static void convert(sbr_PdfRect &dest, const CFX_FloatRect &src)
{
	dest.left = src.left;
	dest.right = src.right;
	dest.bottom = src.bottom;
	dest.top = src.top;
}

static void convert(sbr_PdfRect *dest, const CFX_FloatRect *src, size_t count)
{
	for (int i = 0; i < count; i++)
	{
		convert(dest[i], src[i]);
	}
}

static void convert(sbr_PdfCharInfo &dest, const CPDF_TextPage::CharInfo &src)
{
	dest.unicode = src.m_Unicode;
	dest.nativeCharCode = src.m_CharCode;
	dest.emSize = src.m_CharBox.Height();
	dest.originX = src.m_Origin.x;
	dest.originY = src.m_Origin.y;
	convert(dest.charBox, src.m_CharBox);
	dest.charBox.top = src.m_CharBox.top;
	dest.charType = static_cast<sbr_PdfCharType>(src.m_CharType);
}

sbr_EXPORT int sbr_API
sbr_PdfTextGetCharInfoAt(sbr_PdfText text, int index, sbr_PdfCharInfo *info)
{
	try
	{
		auto pPage = nullCheck(text);
		if (index < 0 || index >= pPage->CountChars())
			throw std::runtime_error("Character index out of range.");
		nullCheck(info);

		auto &charinfo = pPage->GetCharInfo(index);
		convert(*info, charinfo);
		return 0;
	}
	catch (...)
	{
		return -1;
	}
}

sbr_EXPORT int sbr_API sbr_PdfTextGetIndexForPoint(sbr_PdfText text, float x, float y, float xTolerance, float yTolerance)
{
	try
	{
		auto pPage = nullCheck(text);
		return pPage->GetIndexAtPos(CFX_PointF(x, y), CFX_SizeF(xTolerance, yTolerance));
	}
	catch (...)
	{
		return -1;
	}
}

sbr_EXPORT int sbr_API sbr_PdfTextGetRectCount(sbr_PdfText text, int index, int count)
{
	try
	{
		auto pPage = nullCheck(text);
		if (index < 0 || index + count > pPage->CountChars())
			throw std::runtime_error("Character index out of range.");
		return pPage->CountRects(index, count);
	}
	catch (...)
	{
		return -1;
	}
}

// rects: at least equal or larger than the count obtained by sbr_PdfTextGetRectCount
sbr_EXPORT int sbr_API
sbr_PdfTextGetRects(sbr_PdfText text, int index, int count, sbr_PdfRect *rects)
{
	try
	{
		auto pPage = nullCheck(text);
		if (index < 0 || index + count > pPage->CountChars())
			throw std::runtime_error("Character index out of range.");
		nullCheck(rects);

		auto arr = pPage->GetRectArray(index, count);
		convert(rects, &arr[0], arr.size());
		return static_cast<int>(arr.size());
	}
	catch (...)
	{
		return -1;
	}
}

// The returned string should be release with sbr_PdfStringRelease
sbr_EXPORT char *sbr_API sbr_PdfTextGetText(sbr_PdfText text, int index, int count)
{
	try
	{
		auto pPage = nullCheck(text);
		if (count < 0)
			count = -1;
		if (index < 0 || index + count > pPage->CountChars())
			throw std::runtime_error("Character index out of range.");
		auto text = pPage->GetPageText(index, count);
		return generic_strdup(text.ToUTF8().c_str());
	}
	catch (...)
	{
		return nullptr;
	}
}

template <typename RECTA, typename RECTB>
static bool intersect(const RECTA &a, const RECTB &b)
{
	return ((a.left <= b.left && b.left < a.right) || (a.left < b.right && b.right <= a.right)) &&
		   ((a.top <= b.top && b.top < a.bottom) || (a.top < b.bottom && b.bottom <= a.bottom));
}

sbr_EXPORT int
sbr_PdfTextEnumerateCharsInRect(sbr_PdfText text, sbr_PdfRect *rect, void *context, sbr_PdfCharCallback callback)
{
	try
	{
		if (!callback)
			return -1;

		auto pPage = nullCheck(text);
		const auto &all = nullCheck(rect);

		auto count = pPage->CountChars();
		for (int i = 0; i < count; i++)
		{
			auto &charinfo = pPage->GetCharInfo(i);
			if (!intersect(all, charinfo.m_CharBox))
				continue;

			sbr_PdfCharInfo info;
			convert(info, charinfo);
			auto err = callback(context, i, &info);
			if (err)
				return err;
		}
		return 0;
	}
	catch (...)
	{
		return -1;
	}
}

sbr_EXPORT int sbr_API sbr_PdfTextGetRectsByRect(sbr_PdfText text, const sbr_PdfRect *rect, sbr_PdfRect *buffer, int count)
{
	try
	{
		auto pPage = nullCheck(text);
		CFX_FloatRect r(rect->left, rect->bottom, rect->right, rect->top);

		std::vector<CFX_FloatRect> arr;
		int allCount = pPage->CountRects(0, -1);
		for (int i = 0; i < allCount; i++)
		{
			CFX_FloatRect tr;
			pPage->GetRect(i, &tr);
			if (r.Contains(tr))
				arr.push_back(tr);
		}

		auto count0 = arr.size();
		if (buffer && count >= count0)
			convert(buffer, &arr[0], count0);
		return static_cast<int>(count0);
	}
	catch (...)
	{
		return -1;
	}
}

sbr_EXPORT char *sbr_API sbr_PdfTextGetTextByRect(sbr_PdfText text, const sbr_PdfRect *rect)
{
	try
	{
		CFX_FloatRect r(rect->left, rect->bottom, rect->right, rect->top);
		auto s = nullCheck(text)->GetTextByRect(r);
		return generic_strdup(s.ToUTF8().c_str());
	}
	catch (...)
	{
		return nullptr;
	}
}