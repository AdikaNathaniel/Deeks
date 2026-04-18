import { Injectable, NotFoundException } from '@nestjs/common';
import { InjectModel } from '@nestjs/mongoose';
import { Model } from 'mongoose';
import { Link, LinkDocument } from './link.schema';
import { CreateLinkDto } from './dto/create-link.dto';
import { UpdateLinkDto } from './dto/update-link.dto';

@Injectable()
export class LinksService {
  constructor(
    @InjectModel(Link.name) private readonly model: Model<LinkDocument>,
  ) {}

  create(userId: string, dto: CreateLinkDto) {
    return this.model.create({ ...dto, userId });
  }

  findAll(userId: string) {
    return this.model.find({ userId }).sort({ createdAt: -1 }).exec();
  }

  async findOne(userId: string, id: string) {
    const doc = await this.model.findOne({ _id: id, userId }).exec();
    if (!doc) throw new NotFoundException('Link not found');
    return doc;
  }

  async update(userId: string, id: string, dto: UpdateLinkDto) {
    const updated = await this.model
      .findOneAndUpdate({ _id: id, userId }, dto, { new: true })
      .exec();
    if (!updated) throw new NotFoundException('Link not found');
    return updated;
  }

  async remove(userId: string, id: string) {
    const result = await this.model.deleteOne({ _id: id, userId }).exec();
    if (result.deletedCount === 0) throw new NotFoundException('Link not found');
    return { deleted: true };
  }
}
