package handler

import (
	"context"
	"net/http"

	"github.com/google/uuid"

	"github.com/lrprojects/monaserver/internal/db"
	genserver "github.com/lrprojects/monaserver/internal/gen/server"
	"github.com/lrprojects/monaserver/internal/service"
)

type GroupPinDesignsServicer struct {
	designs *service.GroupPinDesignCatalogService
	groups  *service.Group
	guard   *service.Guard
}

func NewGroupPinDesignsServicer(
	designs *service.GroupPinDesignCatalogService,
	groups *service.Group,
	guard *service.Guard,
) *GroupPinDesignsServicer {
	return &GroupPinDesignsServicer{designs: designs, groups: groups, guard: guard}
}

func (s *GroupPinDesignsServicer) GetGroupPinDesignCatalog(ctx context.Context, groupID string) (genserver.ImplResponse, error) {
	id, err := uuid.Parse(groupID)
	if err != nil {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	group, err := s.groups.GetDTO(ctx, id)
	if err != nil {
		return serviceErrResp(ctx, err), nil
	}
	if group.Visibility != 0 {
		uid, ok := ctxUserID(ctx)
		if !ok {
			return genserver.Response(http.StatusUnauthorized, nil), nil
		}
		isMember, err := s.guard.IsGroupMember(ctx, id, uid)
		if err != nil {
			return serviceErrResp(ctx, err), nil
		}
		if !isMember {
			isAdmin, err := s.guard.IsGroupAdmin(ctx, id, uid)
			if err != nil {
				return serviceErrResp(ctx, err), nil
			}
			isMember = isAdmin
		}
		if !isMember {
			return genserver.Response(http.StatusForbidden, nil), nil
		}
	}
	catalog, err := s.designs.Get(ctx, id)
	if err != nil {
		return serviceErrResp(ctx, err), nil
	}
	return genserver.Response(http.StatusOK, toGroupPinDesignCatalogDto(catalog)), nil
}

func (s *GroupPinDesignsServicer) UpdateGroupPinDesignCatalog(ctx context.Context, groupID string, request genserver.UpdateGroupPinDesignCatalogDto) (genserver.ImplResponse, error) {
	id, err := uuid.Parse(groupID)
	if err != nil {
		return genserver.Response(http.StatusBadRequest, nil), nil
	}
	if _, err := s.groups.GetDTO(ctx, id); err != nil {
		return serviceErrResp(ctx, err), nil
	}
	uid, ok := ctxUserID(ctx)
	if !ok {
		return genserver.Response(http.StatusUnauthorized, nil), nil
	}
	isAdmin, err := s.guard.IsGroupAdmin(ctx, id, uid)
	if err != nil {
		return serviceErrResp(ctx, err), nil
	}
	if !isAdmin {
		return genserver.Response(http.StatusForbidden, nil), nil
	}
	catalog, err := s.designs.Update(ctx, id, request.ExpectedRevision, groupPinDesignFromDto(request.Design))
	if err != nil {
		return serviceErrResp(ctx, err), nil
	}
	return genserver.Response(http.StatusOK, toGroupPinDesignCatalogDto(catalog)), nil
}

func toGroupPinDesignCatalogDto(catalog db.GroupPinDesignCatalog) genserver.GroupPinDesignCatalogDto {
	designs := make([]genserver.GroupPinDesignDto, 0, len(catalog.Designs))
	for _, design := range catalog.Designs {
		designs = append(designs, genserver.GroupPinDesignDto{
			Style: genserver.GroupPinDesignStyle(design.Style), Name: design.Name,
			Shape: genserver.GroupPinDesignShape(design.Shape), BodyColor: design.BodyColor,
			OutlineColor: design.OutlineColor, OutlineWidth: float32Ptr(float32(design.OutlineWidth)),
			ImageInset: float32Ptr(float32(design.ImageInset)), ImageZoom: float32(design.ImageZoom),
			ImageAlignmentX: float32Ptr(float32(design.ImageAlignmentX)), ImageAlignmentY: float32Ptr(float32(design.ImageAlignmentY)),
			ImageBorderColor: design.ImageBorderColor, Badge: genserver.GroupPinDesignBadge(design.Badge),
			Shadow: boolPtr(design.Shadow),
		})
	}
	return genserver.GroupPinDesignCatalogDto{Revision: catalog.Revision, Designs: designs}
}

func groupPinDesignFromDto(design genserver.GroupPinDesignDto) db.GroupPinDesign {
	return db.GroupPinDesign{
		Style: string(design.Style), Name: design.Name, Shape: string(design.Shape),
		BodyColor: design.BodyColor, OutlineColor: design.OutlineColor,
		OutlineWidth: float64(*design.OutlineWidth), ImageInset: float64(*design.ImageInset),
		ImageZoom: float64(design.ImageZoom), ImageAlignmentX: float64(*design.ImageAlignmentX),
		ImageAlignmentY: float64(*design.ImageAlignmentY), ImageBorderColor: design.ImageBorderColor,
		Badge: string(design.Badge), Shadow: *design.Shadow,
	}
}

func float32Ptr(value float32) *float32 { return &value }
func boolPtr(value bool) *bool          { return &value }

var _ genserver.GroupPinDesignsAPIServicer = (*GroupPinDesignsServicer)(nil)
